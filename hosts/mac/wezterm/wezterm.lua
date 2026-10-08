local icons = require("icons")
local wezterm = require("wezterm")
local act = wezterm.action
local mux = wezterm.mux

wezterm.on("gui-startup", function(cmd)
  local _, _, window = mux.spawn_window(cmd or {})
  window:gui_window():maximize()
end)

wezterm.on("augment-command-palette", function(_, _)
  return {
    {
      brief = "Rename tab",
      icon = "md_rename_box",

      action = act.PromptInputLine({
        description = "Enter new name for tab",
        action = wezterm.action_callback(function(window, _, line)
          if line then
            window:active_tab():set_title(line)
          end
        end),
      }),
    },
  }
end)

wezterm.on("user-var-changed", function(window, pane, name, value)
  wezterm.log_info("var", name, value)
end)

wezterm.on("user-var-changed", function(window, pane, name, value)
  local overrides = window:get_config_overrides() or {}
  if name == "ZEN_MODE" then
    local incremental = value:find("+")
    local number_value = tonumber(value)
    if incremental ~= nil then
      while number_value > 0 do
        window:perform_action(wezterm.action.IncreaseFontSize, pane)
        number_value = number_value - 1
      end
      overrides.enable_tab_bar = false
    elseif number_value < 0 then
      window:perform_action(wezterm.action.ResetFontSize, pane)
      overrides.font_size = nil
      overrides.enable_tab_bar = true
    else
      overrides.font_size = number_value
      overrides.enable_tab_bar = false
    end
  end
  window:set_config_overrides(overrides)
end)

local config = {}

if wezterm.config_builder then
  config = wezterm.config_builder()
end

config.front_end = "WebGpu"
-- config.front_end = "OpenGL" -- current work-around for https://github.com/wez/wezterm/issues/4825
-- config.enable_wayland = false -- current work-around for https://github.com/wez/wezterm/issues/3121
config.webgpu_power_preference = "HighPerformance"
config.default_cursor_style = "BlinkingBar"
config.force_reverse_video_cursor = true
config.cursor_blink_ease_in = "Constant"
config.cursor_blink_ease_out = "Constant"

-- config.color_scheme_dirs = { wezterm.home_dir .. "/.local/share/nvim/lazy/tokyonight.nvim/extras/wezterm" }
config.color_scheme = "tokyonight_storm"
-- wezterm.add_to_config_reload_watch_list(config.color_scheme_dirs[1] .. config.color_scheme .. ".toml")

if wezterm.target_triple:find("windows") then
  config.default_domain = "WSL:Ubuntu"
  config.window_decorations = "TITLE | RESIZE"
  config.window_frame = {
    active_titlebar_bg = "black",
  }
else
  config.default_domain = "local"
  config.window_decorations = "TITLE | RESIZE"
end

config.window_background_opacity = 0.95

config.term = "wezterm"

config.window_padding = {
  left = 0,
  right = 0,
  top = 0,
  bottom = 0,
}

config.font = wezterm.font({ family = "MonoLisa" })
config.font_size = 11.0
config.bold_brightens_ansi_colors = true

require("tabs").setup(config)
require("keys").setup(config)

return config
