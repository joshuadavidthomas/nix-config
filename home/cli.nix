{ config, pkgs, inputs, ... }:
let
  tokyonight = "${inputs.tokyonight}/extras";
  direnv = "${config.programs.direnv.package}/bin/direnv";
  yaml = pkgs.formats.yaml { };
  toml = pkgs.formats.toml { };
in
{
  programs.atuin = {
    enable = true;
    settings = {
      auto_sync = true;
      sync_address = "https://api.atuin.sh";
      enter_accept = true;
      keymap_mode = "vim-insert";
    };
  };

  programs.bat = {
    enable = true;
    config = {
      theme = "tokyonight_moon";
      italic-text = "always";
    };
    themes.tokyonight_moon = {
      src = inputs.tokyonight;
      file = "extras/sublime/tokyonight_moon.tmTheme";
    };
  };

  programs.btop = {
    enable = true;
    themes.tokyonight_moon = builtins.readFile "${tokyonight}/btop/tokyonight_moon.theme";
    settings = {
      color_theme = "tokyonight_moon";
      save_config_on_exit = false; # the config is read-only; change it here
      theme_background = true;
      truecolor = true;
      force_tty = false;
      disable_presets = "Off";
      presets = "cpu:1:default,proc:0:default cpu:0:default,mem:0:default,net:0:default cpu:0:block,net:0:tty";
      vim_keys = false;
      disable_mouse = false;
      rounded_corners = true;
      terminal_sync = true;
      graph_symbol = "braille";
      graph_symbol_cpu = "default";
      graph_symbol_gpu = "default";
      graph_symbol_mem = "default";
      graph_symbol_net = "default";
      graph_symbol_proc = "default";
      shown_boxes = "cpu mem net proc";
      update_ms = 2000;
      proc_sorting = "memory";
      proc_reversed = false;
      proc_tree = false;
      proc_colors = true;
      proc_gradient = true;
      proc_per_core = true;
      proc_mem_bytes = true;
      proc_cpu_graphs = true;
      proc_info_smaps = false;
      proc_left = false;
      proc_filter_kernel = false;
      proc_follow_detailed = true;
      proc_aggregate = false;
      keep_dead_proc_usage = false;
      cpu_graph_upper = "Auto";
      cpu_graph_lower = "Auto";
      show_gpu_info = "Auto";
      cpu_invert_lower = true;
      cpu_single_graph = false;
      cpu_bottom = false;
      show_uptime = true;
      show_cpu_watts = true;
      check_temp = true;
      cpu_sensor = "Auto";
      show_coretemp = true;
      cpu_core_map = "";
      temp_scale = "celsius";
      base_10_sizes = false;
      show_cpu_freq = true;
      freq_mode = "first";
      clock_format = "%X";
      background_update = true;
      custom_cpu_name = "";
      disks_filter = "";
      mem_graphs = true;
      mem_below_net = false;
      zfs_arc_cached = true;
      show_swap = true;
      swap_disk = true;
      show_disks = true;
      only_physical = true;
      use_fstab = true;
      zfs_hide_datasets = false;
      disk_free_priv = false;
      show_io_stat = true;
      io_mode = false;
      io_graph_combined = false;
      io_graph_speeds = "";
      swap_upload_download = false;
      net_download = 100;
      net_upload = 100;
      net_auto = true;
      net_sync = true;
      net_iface = "";
      base_10_bitrate = "Auto";
      show_battery = true;
      selected_battery = "Auto";
      show_battery_watts = true;
      log_level = "WARNING";
      nvml_measure_pcie_speeds = true;
      rsmi_measure_pcie_speeds = true;
      gpu_mirror_graph = true;
      shown_gpus = "nvidia amd intel apple";
    };
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # direnv's hook fires on the prompt, so shells that never draw one (agents' tool calls,
  # editor tasks, `fish -c`) skip it. These load the directory's environment up front instead.
  # direnv evaluates .envrc in bash, which reads BASH_ENV too: the marker keeps that bash, and
  # anything the .envrc starts, from calling back into direnv. Claude Code loads it its own
  # way (agents.nix).
  programs.zsh.envExtra = ''
    if [[ ! -o interactive && -z ''${DIRENV_NONINTERACTIVE-} && -z ''${CLAUDECODE-} ]]; then
      eval "$(DIRENV_NONINTERACTIVE=1 DIRENV_LOG_FORMAT= ${direnv} export zsh 2>/dev/null)"
    fi
  '';
  home.sessionVariables.BASH_ENV = "${pkgs.writeText "direnv-bash-env" ''
    if [[ -z ''${DIRENV_NONINTERACTIVE-} ]]; then
      eval "$(DIRENV_NONINTERACTIVE=1 DIRENV_LOG_FORMAT= ${direnv} export bash 2>/dev/null)"
    fi
  ''}";
  programs.fish.shellInit = ''
    if not status is-interactive; and not set -q DIRENV_NONINTERACTIVE
      DIRENV_NONINTERACTIVE=1 DIRENV_LOG_FORMAT= ${direnv} export fish 2>/dev/null | source
    end
  '';

  programs.eza = {
    enable = true;
    # integrations would alias ls/ll to eza
    enableBashIntegration = false;
    enableFishIntegration = false;
    enableZshIntegration = false;
  };
  xdg.configFile."eza/theme.yml".source = "${tokyonight}/eza/tokyonight_moon.yml";

  programs.fzf = {
    enable = true;
    # atuin owns ctrl-r
    enableBashIntegration = false;
    enableFishIntegration = false;
    enableZshIntegration = false;
    defaultOptions = [
      "--highlight-line"
      "--info=inline-right"
      "--ansi"
      "--layout=reverse"
      "--border=none"
      "--color=bg+:#2d3f76"
      "--color=bg:#1e2030"
      "--color=border:#589ed7"
      "--color=fg:#c8d3f5"
      "--color=gutter:#1e2030"
      "--color=header:#ff966c"
      "--color=hl+:#65bcff"
      "--color=hl:#65bcff"
      "--color=info:#545c7e"
      "--color=marker:#ff007c"
      "--color=pointer:#ff007c"
      "--color=prompt:#65bcff"
      "--color=query:#c8d3f5:regular"
      "--color=scrollbar:#589ed7"
      "--color=separator:#ff966c"
      "--color=spinner:#ff007c"
    ];
  };

  home.packages = [ pkgs.glow ];
  xdg.configFile."glow/glow.yml".source = yaml.generate "glow.yml" {
    style = "auto";
    mouse = false;
    pager = false;
    width = 88;
  };

  xdg.configFile."herdr/config.toml".source = toml.generate "herdr-config.toml" {
    onboarding = false;
    theme = {
      name = "tokyo-night";
      auto_switch = false;
    };
    terminal.default_shell = "fish";
  };

  programs.lazydocker = {
    enable = true;
  };

  programs.lazygit = {
    enable = true;
  };

  xdg.configFile."posting/config.yaml".source = yaml.generate "posting-config.yaml" {
    theme = "tokyonight-moon";
  };
  xdg.dataFile."posting/themes/tokyonight_moon.yml".source = "${tokyonight}/posting/tokyonight_moon.yml";

  programs.starship = {
    enable = true;
    settings = builtins.fromTOML (builtins.readFile ./dotfiles/starship.toml) // {
      scan_timeout = 100; # ms; default 30
    };
  };

  programs.tmux = {
    enable = true;
    prefix = "C-a";
    historyLimit = 50000;
    terminal = "screen-256color";
    mouse = true;
    baseIndex = 1;
    escapeTime = 10;
    focusEvents = true;
    shell = "${config.programs.fish.package}/bin/fish";
    plugins = [
      {
        plugin = pkgs.tmuxPlugins.resurrect;
        extraConfig = ''
          set -g @resurrect-strategy-nvim 'session'
          set -g @resurrect-capture-pane-contents 'on'
        '';
      }
    ];
    extraConfig = ''
      set -ga terminal-overrides ",*256col*:Tc"

      # Ensure window titles get renamed automatically.
      setw -g automatic-rename

      # Ensure window index numbers get reordered on delete.
      set-option -g renumber-windows on

      # Unbind default keys
      unbind c
      unbind '"'
      unbind %

      # Reload the tmux config.
      bind-key r source-file ~/.config/tmux/tmux.conf

      # Create new window.
      bind-key c new-window -c "#{pane_current_path}"

      # Kill session
      bind-key q kill-session

      # Move windows
      bind-key C-Left swap-window -t -1 -d
      bind-key C-h swap-window -t -1 -d
      bind-key C-Right swap-window -t +1 -d
      bind-key C-l swap-window -t +1 -d

      # Split panes.
      bind-key Up split-window -vb -c "#{pane_current_path}"
      bind-key k split-window -vb -c "#{pane_current_path}"
      bind-key Down split-window -v -c "#{pane_current_path}"
      bind-key j split-window -v -c "#{pane_current_path}"
      bind-key Left split-window -hb -c "#{pane_current_path}"
      bind-key h split-window -hb -c "#{pane_current_path}"
      bind-key Right split-window -h -c "#{pane_current_path}"
      bind-key l split-window -h -c "#{pane_current_path}"

      # Move around panes with ALT + arrow keys.
      bind-key -n M-Up select-pane -U
      bind-key -n M-k select-pane -U
      bind-key -n M-Down select-pane -D
      bind-key -n M-j select-pane -D
      bind-key -n M-Left select-pane -L
      bind-key -n M-h select-pane -L
      bind-key -n M-Right select-pane -R
      bind-key -n M-l select-pane -R

      # Resize panes with CTRL + ALT + arrow keys.
      bind-key -n C-M-Up resize-pane -U
      bind-key -n C-M-k resize-pane -U
      bind-key -n C-M-Down resize-pane -D
      bind-key -n C-M-j resize-pane -D
      bind-key -n C-M-Left resize-pane -L
      bind-key -n C-M-h resize-pane -L
      bind-key -n C-M-Right resize-pane -R
      bind-key -n C-M-l resize-pane -R

      # Fix Home and End keys
      bind-key -n Home send Escape "OH"
      bind-key -n End send Escape "OF"
    '';
  };

  programs.yazi = {
    enable = true; # shell wrapper `y` cds to the directory yazi exits in
  };

  programs.zoxide = {
    enable = true;
  };
}
