-- Mirrors the ghostty keybinds in hosts/mac/home.nix. Every machine gets this file, because
-- each Rex server reads its own: a session on a lab box uses the box's copy. Apply with
-- `rex config reload`, on the machine that runs the server.

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

-- The lab boxes, by their short names: `rex -S lab-1`. Their HTTPS certificates cover only the
-- full names, so a bare `lab-1` can't connect (docs/rex.md).
for _, box in ipairs({ "lab-1", "lab-2", "lab-3" }) do
  rex.host{ label = box, endpoint = "https://" .. box .. ".tail014d2.ts.net:7297" }
end
