# Install a Mac app that has no Homebrew cask from the feed it updates itself from
# (modules/darwin/feed-apps.nix). The app is installed only if its signature is valid and from
# the developer's team.
#
# usage: install-feed-app sparkle|electron FEED TEAM APP DESTINATION
#   sparkle:  FEED is a Sparkle appcast; its first DMG is the newest build, with APP in it.
#   electron: FEED is an electron-updater manifest (<channel>-mac.yml); its zip has APP in it,
#             and the zip must match the manifest's SHA-512.

kind=$1 feed=$2 team=$3 app=$4 destination=$5

tmp=$(mktemp -d)
trap '/usr/bin/hdiutil detach -quiet "$tmp/mnt" 2>/dev/null; rm -rf "$tmp"' EXIT

case $kind in
  sparkle)
    # the newest build is first; no `head` in a pipe, which pipefail would fail on
    urls=$(curl -fsSL "$feed" | grep -o 'url="[^"]*\.dmg"' | cut -d'"' -f2)
    url=${urls%%$'\n'*}
    [ -n "$url" ]
    curl -fsSL "$url" -o "$tmp/app.dmg"
    /usr/bin/hdiutil attach -quiet -nobrowse -readonly -mountpoint "$tmp/mnt" "$tmp/app.dmg"
    source="$tmp/mnt/$app"
    ;;
  electron)
    curl -fsSL "$feed" -o "$tmp/manifest.yml"
    path=$(sed -n 's/^path: //p' "$tmp/manifest.yml")
    sha512=$(sed -n 's/^sha512: //p' "$tmp/manifest.yml")
    [ -n "$path" ] && [ -n "$sha512" ]
    curl -fsSL "${feed%/*}/$(printf '%s' "$path" | sed 's/ /%20/g')" -o "$tmp/app.zip"
    [ "$(openssl dgst -sha512 -binary "$tmp/app.zip" | base64)" = "$sha512" ]
    /usr/bin/ditto -x -k "$tmp/app.zip" "$tmp/expanded"
    source="$tmp/expanded/$app"
    ;;
  *)
    echo "install-feed-app: unknown feed kind $kind" >&2
    exit 1
    ;;
esac

/usr/bin/codesign --verify --deep --strict "$source"
signature=$(/usr/bin/codesign -dv "$source" 2>&1)
grep -qx "TeamIdentifier=$team" <<<"$signature"
/usr/bin/ditto "$source" "$destination"
