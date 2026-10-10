-- Mirrors the ghostty keybinds in ../home.nix. Apply with `rex config reload`.

rex.bind("ctrl+a>r", "client.config.reload")

-- ctrl+a starts sequences, so it never reaches the shell on its own; press it twice
rex.bind("ctrl+a>ctrl+a", "pane.send_key", { key = "ctrl+a" })

rex.bind("ctrl+a>enter", "pane.split.auto")
rex.bind("ctrl+a>\\", "pane.split.right")
rex.bind("ctrl+a>-", "pane.split.down")
rex.bind("ctrl+a>shift+h", "pane.split.left")
rex.bind("ctrl+a>shift+j", "pane.split.down")
rex.bind("ctrl+a>shift+k", "pane.split.up")
rex.bind("ctrl+a>shift+l", "pane.split.right")
rex.bind("ctrl+a>m", "pane.zoom")
rex.bind("ctrl+a>e", "pane.balance")
rex.bind("ctrl+alt+h", "pane.focus.left")
rex.bind("ctrl+alt+j", "pane.focus.down")
rex.bind("ctrl+alt+k", "pane.focus.up")
rex.bind("ctrl+alt+l", "pane.focus.right")

rex.bind("ctrl+a>c", "client.tab.new")
rex.bind("ctrl+a>h", "client.tab.previous")
rex.bind("ctrl+a>l", "client.tab.next")
rex.bind("ctrl+a>,", "client.tab.move.backward")
rex.bind("ctrl+a>.", "client.tab.move.forward")

for i = 1, 9 do
  rex.bind("ctrl+a>" .. i, "client.tab.goto", { index = i })
end

rex.bind("ctrl+a>w", "pane.close")

-- ghostty's text:\n, for newlines in agent prompts
rex.bind("shift+enter", function(ctx, ev)
  rex.block.call("com.superlogical.terminal", "write", {
    block_id = ctx.block_id,
    data = "\n",
  })
  return true
end)
