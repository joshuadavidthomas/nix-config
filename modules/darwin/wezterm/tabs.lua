local w = require("wezterm")
local icons = require("icons")

local M = {}

---@param tab MuxTabObj
---@param max_width number
function M.title(tab, max_width)
  local title = (tab.tab_title and #tab.tab_title > 0) and tab.tab_title or tab.active_pane.title
  local process, other = title:match("^(%S+)%s*%-?%s*%s*(.*)$")

  w.log_info("process: ", process)
  w.log_info("other: ", other)

  if icons.icons[process] then
    title = icons.icons[process] .. " " .. (other or "")
  end

  local is_zoomed = false
  for _, pane in ipairs(tab.panes) do
    if pane.is_zoomed then
      is_zoomed = true
      break
    end
  end
  if is_zoomed then -- or (#tab.panes > 1 and not tab.is_active) then
    title = icons.hamburger .. " " .. title
  end

  title = w.truncate_right(title, max_width - 3)
  return " " .. title .. " "
end

---@param config Config
function M.setup(config)
  config.use_fancy_tab_bar = false
  config.tab_bar_at_bottom = true
  config.hide_tab_bar_if_only_one_tab = false
  config.tab_max_width = 32
  config.unzoom_on_switch_pane = true

  w.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
    local title = M.title(tab, max_width)
    local colors = config.resolved_palette
    local active_bg = colors.tab_bar.active_tab.bg_color
    local inactive_bg = colors.tab_bar.inactive_tab.bg_color

    local tab_idx = 1
    for i, t in ipairs(tabs) do
      if t.tab_id == tab.tab_id then
        tab_idx = i
        break
      end
    end
    local is_last = tab_idx == #tabs
    local next_tab = tabs[tab_idx + 1]
    local next_is_active = next_tab and next_tab.is_active
    local arrow = (tab.is_active or is_last or next_is_active) and icons.arrows.right.solid or icons.arrows.right.thin
    local arrow_bg = inactive_bg
    local arrow_fg = colors.tab_bar.inactive_tab_edge

    if is_last then
      arrow_fg = tab.is_active and active_bg or inactive_bg
      arrow_bg = colors.tab_bar.background
    elseif tab.is_active then
      arrow_bg = inactive_bg
      arrow_fg = active_bg
    elseif next_is_active then
      arrow_bg = active_bg
      arrow_fg = inactive_bg
    end

    local ret = tab.is_active
        and {
          { Attribute = { Intensity = "Bold" } },
          { Attribute = { Italic = true } },
        }
      or {}
    ret[#ret + 1] = { Text = title }
    ret[#ret + 1] = { Foreground = { Color = arrow_fg } }
    ret[#ret + 1] = { Background = { Color = arrow_bg } }
    ret[#ret + 1] = { Text = arrow }
    return ret
  end)

  w.on("update-status", function(window)
    -- Grab the current window's configuration, and from it the
    -- palette (this is the combination of your chosen colour scheme
    -- including any overrides).
    local color_scheme = window:effective_config().resolved_palette
    local bg = color_scheme.brights[1]
    local fg = color_scheme.brights[5]

    window:set_right_status(w.format({
      { Background = { Color = color_scheme.tab_bar.background } },
      { Foreground = { Color = color_scheme.ansi[1] } },
      { Text = icons.arrows.left.solid },
      { Background = { Color = color_scheme.ansi[1] } },
      { Foreground = { Color = color_scheme.ansi[8] } },
      { Text = " " .. window:active_workspace() .. " " },
      -- First, we draw the arrow...
      { Background = { Color = color_scheme.ansi[1] } },
      { Foreground = { Color = bg } },
      { Text = icons.arrows.left.solid },
      -- Then we draw our text
      { Background = { Color = bg } },
      { Foreground = { Color = fg } },
      { Text = " " .. w.hostname() .. " " },
    }))
  end)
end

return M
