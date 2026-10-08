local w = require("wezterm")

local M = {}

M.arrows = {
  left = {
    solid = "",
    thin = "",
  },
  right = {
    solid = "",
    thin = "",
  },
}

M.hamburger = ""

M.icons = {
  ["C:\\WINDOWS\\system32\\cmd.exe"] = w.nerdfonts.md_console_line,
  ["Topgrade"] = w.nerdfonts.md_rocket_launch,
  ["bash"] = w.nerdfonts.cod_terminal_bash,
  ["btm"] = w.nerdfonts.mdi_chart_donut_variant,
  ["cargo"] = w.nerdfonts.dev_rust,
  ["curl"] = w.nerdfonts.mdi_flattr,
  ["docker"] = w.nerdfonts.linux_docker,
  ["docker-compose"] = w.nerdfonts.linux_docker,
  ["fish"] = w.nerdfonts.md_fish,
  ["gh"] = w.nerdfonts.dev_github_badge,
  ["git"] = w.nerdfonts.dev_git,
  ["go"] = w.nerdfonts.seti_go,
  ["htop"] = w.nerdfonts.md_chart_areaspline,
  ["ipython"] = w.nerdfonts.dev_python,
  ["btop"] = w.nerdfonts.md_chart_areaspline,
  ["kubectl"] = w.nerdfonts.linux_docker,
  ["kuberlr"] = w.nerdfonts.linux_docker,
  ["lazydocker"] = w.nerdfonts.linux_docker,
  ["lua"] = w.nerdfonts.seti_lua,
  ["make"] = w.nerdfonts.seti_makefile,
  ["node"] = w.nerdfonts.mdi_hexagon,
  ["nvim"] = w.nerdfonts.custom_vim,
  ["pacman"] = "󰮯 ",
  ["paru"] = "󰮯 ",
  ["psql"] = w.nerdfonts.dev_postgresql,
  ["pwsh.exe"] = w.nerdfonts.md_console,
  ["python"] = w.nerdfonts.dev_python,
  ["ruby"] = w.nerdfonts.cod_ruby,
  ["sudo"] = w.nerdfonts.fa_hashtag,
  ["vim"] = w.nerdfonts.custom_vim,
  ["wget"] = w.nerdfonts.mdi_arrow_down_box,
  ["zsh"] = w.nerdfonts.dev_terminal,
  ["lazygit"] = w.nerdfonts.cod_github,
}

return M
