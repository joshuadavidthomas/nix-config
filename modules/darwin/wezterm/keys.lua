local w = require("wezterm")
local act = w.action

local M = {}

M.mod = {
  ALT = "ALT",
  CTRL = "CTRL",
  LEADER = "LEADER",
  SHIFT = "SHIFT",
}

M.dir = {
  h = "Left",
  j = "Down",
  k = "Up",
  l = "Right",
}

---@param resize_or_move "resize" | "move"
---@param mods string
---@param key string
---@param dir "Right" | "Left" | "Up" | "Down"
function M.split_nav(resize_or_move, mods, key, dir)
  w.log_info("resize_or_move: ", resize_or_move)
  w.log_info("mods: ", mods)
  w.log_info("key: ", key)
  w.log_info("dir: ", dir)
  return {
    key = key,
    mods = mods,
    action = w.action_callback(function(win, pane)
      if pane:get_user_vars().IS_NVIM == "true" then
        w.log_info("IS_NVIM")
        -- pass the keys through to vim/nvim
        win:perform_action({ SendKey = { key = key, mods = mods } }, pane)
      else
        w.log_info("NOT_NVIM")
        if resize_or_move == "resize" then
          win:perform_action({ AdjustPaneSize = { dir, 3 } }, pane)
        else
          local panes = pane:tab():panes_with_info()
          local is_zoomed = false
          for _, p in ipairs(panes) do
            if p.is_zoomed then
              is_zoomed = true
            end
          end
          w.log_info("is_zoomed: " .. tostring(is_zoomed))
          if is_zoomed then
            dir = dir == "Up" or dir == "Right" and "Next" or "Prev"
            w.log_info("dir: " .. dir)
          end
          win:perform_action({ ActivatePaneDirection = dir }, pane)
          win:perform_action({ SetPaneZoomState = is_zoomed }, pane)
        end
      end
    end),
  }
end

---@param config Config
function M.setup(config)
  config.disable_default_key_bindings = true
  config.debug_key_events = true
  config.leader = { key = "a", mods = M.mod.CTRL, timeout_milliseconds = 3000 }
  config.keys = {
    { key = "d", mods = M.mod.LEADER, action = act.ShowDebugOverlay },
    { key = "p", mods = M.mod.LEADER, action = act.ActivateCommandPalette },
    { key = "F11", action = act.ToggleFullScreen },
    -- font size
    { key = "-", mods = M.mod.CTRL, action = act.DecreaseFontSize },
    { key = "=", mods = M.mod.CTRL, action = act.IncreaseFontSize },
    { key = "0", mods = M.mod.CTRL, action = act.ResetFontSize },
    -- clipboard
    { key = "v", mods = M.mod.CTRL, action = act.PasteFrom("Clipboard") },
    { key = "X", mods = M.mod.CTRL .. "|" .. M.mod.SHIFT, action = act.ActivateCopyMode },
    -- new tab
    { key = "c", mods = M.mod.LEADER, action = act.SpawnTab("CurrentPaneDomain") },
    { key = "w", mods = M.mod.LEADER, action = act.CloseCurrentPane({ confirm = false }) },
    { key = "s", mods = M.mod.LEADER, action = w.action.PaneSelect({ mode = "SwapWithActive" }) },
    { key = "m", mods = M.mod.LEADER, action = act.TogglePaneZoomState },
    M.split_nav("resize", M.mod.CTRL, "LeftArrow", "Left"),
    M.split_nav("resize", M.mod.CTRL, "RightArrow", "Right"),
    M.split_nav("resize", M.mod.CTRL, "UpArrow", "Up"),
    M.split_nav("resize", M.mod.CTRL, "DownArrow", "Down"),
    M.split_nav("move", M.mod.CTRL, "h", "Left"),
    M.split_nav("move", M.mod.CTRL, "j", "Down"),
    M.split_nav("move", M.mod.CTRL, "k", "Up"),
    M.split_nav("move", M.mod.CTRL, "l", "Right"),
    { key = "-", mods = M.mod.LEADER, action = act.SplitPane({ direction = "Down" }) },
    { key = "\\", mods = M.mod.LEADER, action = act.SplitPane({ direction = "Right" }) },
  }

  for key, dir in pairs(M.dir) do
    table.insert(config.keys, { key = key, mods = M.mod.LEADER, action = act.SplitPane({ direction = dir }) })
    table.insert(
      config.keys,
      { key = string.format(dir .. "Arrow"), mods = M.mod.LEADER, action = act.SplitPane({ direction = dir }) }
    )
  end

  for i = 1, 8 do
    table.insert(config.keys, {
      key = tostring(i),
      mods = M.mod.LEADER,
      action = act.ActivateTab(i - 1),
    })
  end
end

return M
