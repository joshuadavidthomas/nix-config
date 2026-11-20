#!/usr/bin/env python3
"""Sync declarative web-app shortcuts, SteamGridDB artwork, and Steam Input templates.

Runs before steam-launcher.service so Steam reads the updated shortcuts.vdf and
Steam Controller Configs on startup rather than overwriting them from memory.

- shortcuts.vdf: merges only the shortcuts Nix owns (tracked in nix-managed-webapps.json),
  leaving EmuDeck, Heroic, Battle.net, and every other non-Steam shortcut untouched.
- config/grid/: fetches missing SteamGridDB artwork only for empty slots so custom art
  picked in Game Mode (e.g. decky-steamgriddb) sticks across rebuilds and reboots.
- controller_base/templates/ + Steam Controller Configs/<id>/config/configset_*.vdf:
  writes deterministic Steam Input templates ("tv" for leanback arrow-key UIs like
  YouTube TV, "browser" for mouse+scroll desktop sites like Twitch/Disney+) across all
  common controller types (Xbox 360/One/Elite, DualSense/DS4, Switch Pro, Steam Deck).
  Only sets/updates entries that are missing or already point to a nix_webapp_* template,
  so any manual layout edits saved in Steam's UI are preserved.
"""

from __future__ import annotations

import json
import os
import re
import struct
import sys
import tempfile
import urllib.parse
import urllib.request
import zlib
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

SGDB_BASE = "https://www.steamgriddb.com"
SGDB_HEADERS = {
    "User-Agent": "Mozilla/5.0",
    "Accept": "application/json",
}
IMAGE_EXTS = (".png", ".jpg", ".jpeg", ".webp", ".ico")

CONTROLLER_TYPES = (
    "controller_xbox360",
    "controller_xboxone",
    "controller_xboxelite",
    "controller_ps5",
    "controller_ps5_edge",
    "controller_ps4",
    "controller_switch_pro",
    "controller_neptune",
)
TRACKPAD_CONTROLLERS = {
    "controller_neptune",
    "controller_ps4",
    "controller_ps5",
    "controller_ps5_edge",
}


# ---------------------------------------------------------------------------
# Binary VDF (shortcuts.vdf)
# ---------------------------------------------------------------------------

def read_cstring(buf: bytes, pos: int) -> tuple[str, int]:
    end = buf.index(b"\x00", pos)
    return buf[pos:end].decode("utf-8", "surrogateescape"), end + 1


def parse_vdf(buf: bytes, pos: int = 0) -> tuple[dict, int]:
    result: dict = {}
    while pos < len(buf):
        tag = buf[pos]
        pos += 1
        if tag == 0x08:
            return result, pos
        key, pos = read_cstring(buf, pos)
        if tag == 0x00:
            val, pos = parse_vdf(buf, pos)
        elif tag == 0x01:
            val, pos = read_cstring(buf, pos)
        elif tag == 0x02:
            val = struct.unpack_from("<i", buf, pos)[0]
            pos += 4
        else:
            raise ValueError(f"Unsupported binary VDF tag 0x{tag:02x} at byte {pos - 1}")
        result[key] = val
    return result, pos


def dump_vdf(data: dict) -> bytes:
    out = bytearray()
    for key, val in data.items():
        key_bytes = key.encode("utf-8", "surrogateescape") + b"\x00"
        if isinstance(val, dict):
            out.append(0x00)
            out.extend(key_bytes)
            out.extend(dump_vdf(val))
        elif isinstance(val, str):
            out.append(0x01)
            out.extend(key_bytes)
            out.extend(val.encode("utf-8", "surrogateescape") + b"\x00")
        elif isinstance(val, int):
            out.append(0x02)
            out.extend(key_bytes)
            out.extend(struct.pack("<i", val))
        else:
            raise TypeError(f"Unsupported VDF value type {type(val).__name__} for {key!r}")
    out.append(0x08)
    return bytes(out)


# ---------------------------------------------------------------------------
# Text VDF (configset_*.vdf)
# ---------------------------------------------------------------------------

def _tokenize_text_vdf(text: str) -> list[str]:
    tokens: list[str] = []
    i = 0
    n = len(text)
    if n > 0 and text[0] == "\ufeff":
        i = 1
    while i < n:
        ch = text[i]
        if ch.isspace():
            i += 1
        elif ch == "/" and i + 1 < n and text[i + 1] == "/":
            nl = text.find("\n", i)
            i = n if nl == -1 else nl + 1
        elif ch in "{}":
            tokens.append(ch)
            i += 1
        elif ch == '"':
            i += 1
            buf: list[str] = []
            while i < n:
                c = text[i]
                if c == "\\" and i + 1 < n:
                    nxt = text[i + 1]
                    if nxt in ('"', "\\"):
                        buf.append(nxt)
                        i += 2
                    elif nxt == "n":
                        buf.append("\n")
                        i += 2
                    elif nxt == "t":
                        buf.append("\t")
                        i += 2
                    else:
                        # Preserve unknown escape sequences (e.g. \' in SRM entries)
                        buf.append("\\")
                        buf.append(nxt)
                        i += 2
                elif c == '"':
                    i += 1
                    break
                else:
                    buf.append(c)
                    i += 1
            tokens.append('"' + "".join(buf))
        else:
            start = i
            while i < n and not text[i].isspace() and text[i] not in '{}""':
                i += 1
            tokens.append('"' + text[start:i])
    return tokens


def _parse_text_vdf_block(tokens: list[str], idx: int) -> tuple[dict, int]:
    result: dict = {}
    while idx < len(tokens):
        tok = tokens[idx]
        if tok == "}":
            return result, idx + 1
        if not tok.startswith('"'):
            raise ValueError(f"Unexpected token {tok!r} at index {idx}")
        key = tok[1:]
        idx += 1
        if idx >= len(tokens):
            raise ValueError(f"Unexpected EOF after key {key!r}")
        nxt = tokens[idx]
        if nxt == "{":
            val, idx = _parse_text_vdf_block(tokens, idx + 1)
        elif nxt.startswith('"'):
            val = nxt[1:]
            idx += 1
        else:
            raise ValueError(f"Unexpected token {nxt!r} after key {key!r}")
        result[key] = val
    return result, idx


def parse_text_vdf(text: str) -> dict:
    tokens = _tokenize_text_vdf(text)
    data, _ = _parse_text_vdf_block(tokens, 0)
    return data


def _escape_vdf_str(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\t", "\\t")


def dump_text_vdf(data: dict, indent: int = 0) -> str:
    lines: list[str] = []
    pad = "\t" * indent
    for key, val in data.items():
        ek = _escape_vdf_str(str(key))
        if isinstance(val, dict):
            lines.append(f'{pad}"{ek}"')
            lines.append(f"{pad}{{")
            if val:
                lines.append(dump_text_vdf(val, indent + 1))
            lines.append(f"{pad}}}")
        else:
            ev = _escape_vdf_str(str(val))
            lines.append(f'{pad}"{ek}"\t\t"{ev}"')
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Steam Input controller templates
# ---------------------------------------------------------------------------

def _binding_block(input_name: str, binding: str, extra_settings: dict[str, str] | None = None) -> str:
    settings_block = ""
    if extra_settings:
        s_lines = "\n".join(f'\t\t\t\t\t\t\t"{k}"\t\t"{v}"' for k, v in extra_settings.items())
        settings_block = f'\n\t\t\t\t\t\t"settings"\n\t\t\t\t\t\t{{\n{s_lines}\n\t\t\t\t\t\t}}'
    return f"""\t\t\t"{input_name}"
\t\t\t{{
\t\t\t\t"activators"
\t\t\t\t{{
\t\t\t\t\t"Full_Press"
\t\t\t\t\t{{
\t\t\t\t\t\t"bindings"
\t\t\t\t\t\t{{
\t\t\t\t\t\t\t"binding"\t\t"{binding}"
\t\t\t\t\t\t}}{settings_block}
\t\t\t\t\t}}
\t\t\t\t}}
\t\t\t}}"""


def render_controller_template(layout: str, controller_type: str) -> str:
    filename = f"nix_webapp_{layout}_{controller_type}.vdf"
    has_trackpad = controller_type in TRACKPAD_CONTROLLERS
    rpad_state = "right_trackpad active" if has_trackpad else "right_trackpad inactive"

    if layout == "tv":
        title = "Nix Web App (TV / Remote)"
        desc = "Arrow-key and Enter/Escape layout for 10-foot TV web apps like YouTube TV, with right stick mouse fallback."
        face = [
            _binding_block("button_a", "key_press RETURN, Select"),
            _binding_block("button_b", "key_press ESCAPE, Back"),
            _binding_block("button_x", "key_press SPACE, Play/Pause"),
            _binding_block("button_y", "key_press S, Search"),
        ]
        lstick = [
            _binding_block("dpad_north", "key_press UP_ARROW, Up"),
            _binding_block("dpad_south", "key_press DOWN_ARROW, Down"),
            _binding_block("dpad_east", "key_press RIGHT_ARROW, Right"),
            _binding_block("dpad_west", "key_press LEFT_ARROW, Left"),
        ]
        dpad = list(lstick)
        switches = [
            _binding_block("button_escape", "key_press ESCAPE, Back"),
            _binding_block("button_menu", "key_press SPACE, Play/Pause"),
            _binding_block("left_bumper", "key_press LEFT_ARROW, Rewind"),
            _binding_block("right_bumper", "key_press RIGHT_ARROW, Fast Forward"),
        ]
    elif layout == "browser":
        title = "Nix Web App (Browser)"
        desc = "Mouse and scroll layout for desktop web apps like Twitch and Disney+."
        face = [
            _binding_block("button_a", "mouse_button LEFT, Click"),
            _binding_block("button_b", "key_press ESCAPE, Back"),
            _binding_block("button_x", "key_press SPACE, Play/Pause"),
            _binding_block("button_y", "key_press F, Fullscreen"),
        ]
        lstick = [
            _binding_block("dpad_north", "mouse_wheel SCROLL_UP, Scroll Up"),
            _binding_block("dpad_south", "mouse_wheel SCROLL_DOWN, Scroll Down"),
            _binding_block("dpad_east", "key_press RIGHT_ARROW, Right"),
            _binding_block("dpad_west", "key_press LEFT_ARROW, Left"),
        ]
        dpad = [
            _binding_block("dpad_north", "key_press UP_ARROW, Up"),
            _binding_block("dpad_south", "key_press DOWN_ARROW, Down"),
            _binding_block("dpad_east", "key_press RIGHT_ARROW, Right"),
            _binding_block("dpad_west", "key_press LEFT_ARROW, Left"),
        ]
        switches = [
            _binding_block("button_escape", "key_press ESCAPE, Escape"),
            _binding_block("button_menu", "key_press SPACE, Play/Pause"),
            _binding_block("left_bumper", "mouse_wheel SCROLL_UP, Scroll Up"),
            _binding_block("right_bumper", "mouse_wheel SCROLL_DOWN, Scroll Down"),
        ]
    else:
        raise ValueError(f"Unknown controllerLayout {layout!r}")

    return f""""controller_mappings"
{{
\t"version"\t\t"3"
\t"revision"\t\t"1"
\t"title"\t\t"{title}"
\t"description"\t\t"{desc}"
\t"url"\t\t"template://{filename}"
\t"export_type"\t\t"template"
\t"controller_type"\t\t"{controller_type}"
\t"group"
\t{{
\t\t"id"\t\t"0"
\t\t"mode"\t\t"four_buttons"
\t\t"inputs"
\t\t{{
{chr(10).join(face)}
\t\t}}
\t}}
\t"group"
\t{{
\t\t"id"\t\t"2"
\t\t"mode"\t\t"absolute_mouse"
\t\t"inputs"
\t\t{{
{_binding_block("click", "mouse_button LEFT, Click")}
\t\t}}
\t\t"settings"
\t\t{{
\t\t\t"sensitivity"\t\t"145"
\t\t}}
\t}}
\t"group"
\t{{
\t\t"id"\t\t"3"
\t\t"mode"\t\t"dpad"
\t\t"inputs"
\t\t{{
{chr(10).join(lstick)}
\t\t}}
\t\t"settings"
\t\t{{
\t\t\t"requires_click"\t\t"0"
\t\t\t"layout"\t\t"0"
\t\t\t"haptic_intensity_override"\t\t"0"
\t\t}}
\t}}
\t"group"
\t{{
\t\t"id"\t\t"4"
\t\t"mode"\t\t"trigger"
\t\t"inputs"
\t\t{{
{_binding_block("edge", "mouse_button RIGHT, Right Click")}
\t\t}}
\t}}
\t"group"
\t{{
\t\t"id"\t\t"5"
\t\t"mode"\t\t"trigger"
\t\t"inputs"
\t\t{{
{_binding_block("edge", "mouse_button LEFT, Left Click")}
\t\t}}
\t}}
\t"group"
\t{{
\t\t"id"\t\t"6"
\t\t"mode"\t\t"switches"
\t\t"inputs"
\t\t{{
{chr(10).join(switches)}
\t\t}}
\t}}
\t"group"
\t{{
\t\t"id"\t\t"7"
\t\t"mode"\t\t"dpad"
\t\t"inputs"
\t\t{{
{chr(10).join(dpad)}
\t\t}}
\t\t"settings"
\t\t{{
\t\t\t"requires_click"\t\t"0"
\t\t\t"layout"\t\t"0"
\t\t}}
\t}}
\t"group"
\t{{
\t\t"id"\t\t"9"
\t\t"mode"\t\t"joystick_mouse"
\t\t"inputs"
\t\t{{
{_binding_block("click", "mouse_button LEFT, Click")}
\t\t}}
\t}}
\t"preset"
\t{{
\t\t"id"\t\t"0"
\t\t"name"\t\t"Default"
\t\t"group_source_bindings"
\t\t{{
\t\t\t"0"\t\t"button_diamond active"
\t\t\t"2"\t\t"{rpad_state}"
\t\t\t"3"\t\t"joystick active"
\t\t\t"4"\t\t"left_trigger active"
\t\t\t"5"\t\t"right_trigger active"
\t\t\t"6"\t\t"switch active"
\t\t\t"7"\t\t"dpad active"
\t\t\t"9"\t\t"right_joystick active"
\t\t}}
\t}}
\t"settings"
\t{{
\t\t"left_trackpad_mode"\t\t"0"
\t\t"right_trackpad_mode"\t\t"0"
\t}}
}}
"""


def configset_app_key(name: str) -> str:
    """Match Steam's lowercase filename-safe key for non-Steam shortcuts in configset_*.vdf."""
    cleaned = re.sub(r'[:/\\*?"<>|.]', "", name.lower()).strip()
    return re.sub(r"\s+", " ", cleaned)


def sync_controller_templates(steam_dir: Path, userdata_dirs: list[Path], apps: list[dict]) -> None:
    needed_layouts = sorted({app["controllerLayout"] for app in apps if app.get("controllerLayout")})
    templates_dir = steam_dir / "controller_base" / "templates"
    templates_dir.mkdir(parents=True, exist_ok=True)

    for layout in needed_layouts:
        for ctype in CONTROLLER_TYPES:
            dest = templates_dir / f"nix_webapp_{layout}_{ctype}.vdf"
            content = render_controller_template(layout, ctype).encode("utf-8")
            if not dest.is_file() or dest.read_bytes() != content:
                atomic_write(dest, content)

    desired_by_key = {
        configset_app_key(app["name"]): app["controllerLayout"]
        for app in apps
        if app.get("controllerLayout")
    }

    for udir in userdata_dirs:
        steamid3 = udir.name
        cfg_dir = steam_dir / "steamapps" / "common" / "Steam Controller Configs" / steamid3 / "config"
        cfg_dir.mkdir(parents=True, exist_ok=True)

        for ctype in CONTROLLER_TYPES:
            cfg_path = cfg_dir / f"configset_{ctype}.vdf"
            if cfg_path.is_file():
                original_text = cfg_path.read_text(encoding="utf-8", errors="surrogateescape")
                parsed = parse_text_vdf(original_text)
            else:
                original_text = None
                parsed = {}

            cc = parsed.get("controller_config")
            if not isinstance(cc, dict):
                cc = {}
                parsed["controller_config"] = cc

            changed = False

            # Set or update entries we own (missing or already pointing to nix_webapp_*)
            for app_key, layout in desired_by_key.items():
                tpl_name = f"nix_webapp_{layout}_{ctype}.vdf"
                existing = cc.get(app_key)
                if existing is None:
                    cc[app_key] = {"template": tpl_name}
                    changed = True
                elif isinstance(existing, dict) and str(existing.get("template", "")).startswith("nix_webapp_"):
                    if existing.get("template") != tpl_name:
                        existing["template"] = tpl_name
                        changed = True

            # Remove stale nix_webapp_* entries for apps removed from Nix or set to null
            for app_key in list(cc.keys()):
                entry = cc[app_key]
                if (
                    app_key not in desired_by_key
                    and isinstance(entry, dict)
                    and str(entry.get("template", "")).startswith("nix_webapp_")
                ):
                    del cc[app_key]
                    changed = True

            if changed or (original_text is None and cc):
                new_text = dump_text_vdf(parsed) + "\n"
                atomic_write(cfg_path, new_text.encode("utf-8", errors="surrogateescape"))


# ---------------------------------------------------------------------------
# Shortcuts & SteamGridDB artwork
# ---------------------------------------------------------------------------

def shortcut_appids(exe: str, name: str) -> tuple[int, int]:
    """Return (signed_int32, unsigned_uint32) Steam shortcut AppIDs."""
    unsigned = (zlib.crc32((exe + name).encode("utf-8")) | 0x80000000) & 0xFFFFFFFF
    signed = unsigned - 0x100000000 if unsigned >= 0x80000000 else unsigned
    return signed, unsigned


def entry_name(entry: dict) -> str:
    return str(entry.get("AppName") or entry.get("appname") or "")


def set_entry_name(entry: dict, name: str) -> None:
    if "appname" in entry and "AppName" not in entry:
        entry["appname"] = name
    else:
        entry["AppName"] = name


def sgdb_json(url: str, payload: dict | None = None) -> dict:
    headers = dict(SGDB_HEADERS)
    body = None
    if payload is not None:
        headers["Content-Type"] = "application/json"
        body = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=body,
        headers=headers,
        method="POST" if payload is not None else "GET",
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read().decode("utf-8"))


def normalize_title(name: str) -> str:
    cleaned = re.sub(r"[™®©]", "", name.lower().strip())
    cleaned = re.sub(r"[^\w\s]", "", cleaned)
    return re.sub(r"\s+", " ", cleaned).strip()


def resolve_sgdb_game_id(name: str, configured_id: int | None) -> int | None:
    if configured_id is not None:
        return configured_id
    params = urllib.parse.urlencode({"term": name})
    try:
        games = sgdb_json(f"{SGDB_BASE}/api/public/search/autocomplete?{params}").get("data", [])
    except Exception as exc:
        print(f"steam-webapps: SteamGridDB search failed for {name!r}: {exc}", file=sys.stderr)
        return None
    if not games:
        return None
    target = normalize_title(name)
    for game in games:
        if normalize_title(game.get("name", "")) == target:
            return int(game["id"])
    return int(games[0]["id"])


def fetch_sgdb_asset_url(game_id: int, asset_type: str, dimensions: str = "all") -> str | None:
    payload = {
        "styles": ["all"],
        "languages": ["en"],
        "dimensions": [dimensions],
        "formats": ["all"],
        "order": "score_desc",
        "game_id": [game_id],
        "static": True,
        "animated": False,
        "nsfw": False,
        "epilepsy": False,
        "humor": False,
        "untagged": True,
        "asset_type": asset_type,
        "page": 0,
        "limit": 1,
        "user_steam64": None,
        "user_steam64_likes": None,
    }
    try:
        assets = sgdb_json(f"{SGDB_BASE}/api/public/search/assets", payload).get("data", {}).get("assets", [])
    except Exception as exc:
        print(f"steam-webapps: SteamGridDB {asset_type} lookup failed for {game_id}: {exc}", file=sys.stderr)
        return None
    if not assets:
        return None
    asset = assets[0]
    url = asset.get("url")
    thumb = asset.get("thumb")
    # Steam on Linux prefers PNG icons over .ico; SteamGridDB serves 512x512 PNG in thumb.
    if asset_type == "icon" and isinstance(url, str) and url.lower().endswith(".ico") and isinstance(thumb, str) and thumb.lower().endswith(".png"):
        return thumb
    return url


def find_existing_art(grid_dir: Path, stem: str) -> Path | None:
    for ext in IMAGE_EXTS:
        candidate = grid_dir / f"{stem}{ext}"
        if candidate.is_file():
            return candidate
    return None


def download_file(url: str, dest: Path) -> bool:
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Mozilla/5.0 (X11; Linux x86_64)",
            "Referer": f"{SGDB_BASE}/",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            content = resp.read()
    except Exception as exc:
        print(f"steam-webapps: failed downloading {url}: {exc}", file=sys.stderr)
        return False

    atomic_write(dest, content)
    return True


def ensure_artwork(grid_dir: Path, unsigned_id: int, app: dict) -> Path | None:
    """Download missing SteamGridDB artwork slots; return the icon path if available."""
    slots = [
        ("grid_portrait", f"{unsigned_id}p", "grid", "600x900"),
        ("grid_landscape", f"{unsigned_id}", "grid", "920x430"),
        ("hero", f"{unsigned_id}_hero", "hero", "all"),
        ("logo", f"{unsigned_id}_logo", "logo", "all"),
        ("icon", f"{unsigned_id}_icon", "icon", "all"),
    ]

    existing = {slot: find_existing_art(grid_dir, stem) for slot, stem, _, _ in slots}
    missing = [(slot, stem, atype, dim) for slot, stem, atype, dim in slots if existing[slot] is None]

    if not missing:
        return existing["icon"]

    game_id = resolve_sgdb_game_id(app["name"], app.get("steamGridDbId"))
    if game_id is None:
        return existing["icon"]

    def fetch_slot(item: tuple[str, str, str, str]) -> tuple[str, Path | None]:
        slot, stem, atype, dim = item
        url = fetch_sgdb_asset_url(game_id, atype, dim)
        if not url:
            return slot, None
        ext = Path(urllib.parse.urlsplit(url).path).suffix.lower()
        if ext not in IMAGE_EXTS:
            ext = ".png"
        dest = grid_dir / f"{stem}{ext}"
        return slot, (dest if download_file(url, dest) else None)

    with ThreadPoolExecutor(max_workers=5) as pool:
        for slot, path in pool.map(fetch_slot, missing):
            if path is not None:
                existing[slot] = path

    return existing["icon"]


def find_userdata_dirs(steam_dir: Path) -> list[Path]:
    userdata = steam_dir / "userdata"
    if not userdata.is_dir():
        return []
    dirs = []
    for child in sorted(userdata.iterdir()):
        if child.is_dir() and child.name.isdigit() and child.name != "0":
            dirs.append(child)
    return dirs


def atomic_write(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(data)
        os.replace(tmp_name, path)
    except Exception:
        if os.path.exists(tmp_name):
            os.unlink(tmp_name)
        raise


def sync_userdata(userdata_dir: Path, apps: list[dict], fetch_art: bool) -> None:
    config_dir = userdata_dir / "config"
    config_dir.mkdir(parents=True, exist_ok=True)
    shortcuts_path = config_dir / "shortcuts.vdf"
    grid_dir = config_dir / "grid"
    state_path = config_dir / "nix-managed-webapps.json"

    if shortcuts_path.is_file():
        original_bytes = shortcuts_path.read_bytes()
        data, _ = parse_vdf(original_bytes)
        shortcuts_dict = data.get("shortcuts", {})
    else:
        original_bytes = None
        shortcuts_dict = {}

    if state_path.is_file():
        prev_state = json.loads(state_path.read_text(encoding="utf-8"))
    else:
        prev_state = {"managed": {}}
    prev_managed: dict[str, int] = prev_state.get("managed", {})
    prev_appids = set(prev_managed.values())

    # Preserve existing order of shortcuts
    entries: list[dict] = [
        shortcuts_dict[k] for k in sorted(shortcuts_dict.keys(), key=lambda x: int(x) if x.isdigit() else 999999)
    ]

    desired_managed: dict[str, int] = {}
    desired_appids: set[int] = set()

    for app in apps:
        name = app["name"]
        exe = app["exe"]
        start_dir = app["startDir"]
        launch_options = app["launchOptions"]
        signed_id, unsigned_id = shortcut_appids(exe, name)
        desired_managed[name] = signed_id
        desired_appids.add(signed_id)

        icon_path = ensure_artwork(grid_dir, unsigned_id, app) if fetch_art else find_existing_art(grid_dir, f"{unsigned_id}_icon")
        icon_str = str(icon_path) if icon_path is not None else ""

        # Match existing shortcut by signed_id, or by previously managed ID for the same name
        match = None
        prev_id_for_name = prev_managed.get(name)
        for entry in entries:
            eid = entry.get("appid")
            if eid == signed_id or (prev_id_for_name is not None and eid == prev_id_for_name):
                match = entry
                break

        if match is not None:
            match["appid"] = signed_id
            set_entry_name(match, name)
            match["Exe"] = exe
            match["StartDir"] = start_dir
            match["LaunchOptions"] = launch_options
            if icon_str and not (match.get("icon") and Path(match["icon"]).is_file()):
                match["icon"] = icon_str
        else:
            entries.append(
                {
                    "appid": signed_id,
                    "AppName": name,
                    "Exe": exe,
                    "StartDir": start_dir,
                    "icon": icon_str,
                    "ShortcutPath": "",
                    "LaunchOptions": launch_options,
                    "IsHidden": 0,
                    "AllowDesktopConfig": 1,
                    "AllowOverlay": 1,
                    "OpenVR": 0,
                    "Devkit": 0,
                    "DevkitGameID": "",
                    "DevkitOverrideAppID": 0,
                    "LastPlayTime": 0,
                    "FlatpakAppID": "",
                    "tags": {},
                }
            )

    # Drop shortcuts that Nix used to manage but were removed from config
    removed_appids = prev_appids - desired_appids
    if removed_appids:
        entries = [e for e in entries if e.get("appid") not in removed_appids]

    new_vdf = {"shortcuts": {str(i): entry for i, entry in enumerate(entries)}}
    new_bytes = dump_vdf(new_vdf)

    if new_bytes != original_bytes:
        atomic_write(shortcuts_path, new_bytes)

    new_state_bytes = (json.dumps({"managed": desired_managed}, indent=2, sort_keys=True) + "\n").encode("utf-8")
    if not state_path.is_file() or state_path.read_bytes() != new_state_bytes:
        atomic_write(state_path, new_state_bytes)


def main() -> int:
    if len(sys.argv) < 2:
        print(f"usage: {sys.argv[0]} <config.json> [steam_dir]", file=sys.stderr)
        return 2

    cfg = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    steam_dir = Path(sys.argv[2]) if len(sys.argv) > 2 else Path(cfg["steamDir"])
    fetch_art = bool(cfg.get("fetchArtwork", True))
    apps = cfg.get("apps", [])

    userdata_dirs = find_userdata_dirs(steam_dir)
    if not userdata_dirs:
        print(f"steam-webapps: no Steam userdata directory found under {steam_dir}", file=sys.stderr)
        return 0

    for udir in userdata_dirs:
        sync_userdata(udir, apps, fetch_art)

    sync_controller_templates(steam_dir, userdata_dirs, apps)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
