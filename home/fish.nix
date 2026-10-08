{ ... }: {
  programs.fish = {
    enable = true;

    interactiveShellInit = ''
      set -g fish_greeting

      # tokyonight moon
      set -g fish_color_normal c8d3f5
      set -g fish_color_command 86e1fc
      set -g fish_color_keyword c099ff
      set -g fish_color_quote ffc777
      set -g fish_color_redirection c8d3f5
      set -g fish_color_end ff966c
      set -g fish_color_option c099ff
      set -g fish_color_error ff757f
      set -g fish_color_param fca7ea
      set -g fish_color_comment 636da6
      set -g fish_color_selection --background=2d3f76
      set -g fish_color_search_match --background=2d3f76
      set -g fish_color_operator c3e88d
      set -g fish_color_escape c099ff
      set -g fish_color_autosuggestion 636da6
      set -g fish_pager_color_progress 636da6
      set -g fish_pager_color_prefix 86e1fc
      set -g fish_pager_color_completion c8d3f5
      set -g fish_pager_color_description 636da6
      set -g fish_pager_color_selected_background --background=2d3f76
    '';

    shellAbbrs = {
      "-" = "cd -";
      dotdot = {
        regex = "^\\.\\.+$";
        function = "multicd";
      };
    };

    functions = {
      multicd = ''
        echo cd (string repeat -n (math (string length -- $argv[1]) - 1) ../)
      '';

      gi = ''
        curl -sL https://www.toptal.com/developers/gitignore/api/$argv
      '';

      llm = {
        wraps = "llm";
        body = ''
          set -l pipe_commands prompt

          # Pipe through glow if ANY of these are true:
          # 1. No arguments are given OR
          # 2. The first argument is in pipe_commands OR
          # 3. The first argument starts with a hyphen
          if test (count $argv) -eq 0; or contains -- $argv[1] $pipe_commands; or string match -q -- '-*' $argv[1]
              command llm $argv | glow -
          else
              command llm $argv
          end
        '';
      };

      rconf = ''
        # Reload fish configuration
        source $HOME/.config/fish/config.fish
      '';

      __fish_projects_dir = ''
        if set -q PROJECTS_DIR; and test -n "$PROJECTS_DIR"
            printf '%s\n' "$PROJECTS_DIR"
        else if test -d "$HOME/Code"
            printf '%s\n' "$HOME/Code"
        else
            printf '%s\n' "$HOME/projects"
        end
      '';

      workon = {
        argumentNames = "project_name";
        body = ''
          set -l projects_dir (__fish_projects_dir)
          set -l projects_file "$projects_dir/.projects"

          mkdir -p "$projects_dir"

          if not test -f $projects_file
              touch $projects_file
          end

          if test -z "$project_name"
              set project_name (basename (pwd))
          end

          set -l repo_url ""

          if string match -q 'gh:*' -- $project_name
              set repo_url (string replace 'gh:' 'https://github.com/' $project_name)
          else if string match -q -r '^https?://' -- $project_name
              set repo_url $project_name
          end

          if test -n "$repo_url"
              set project_name (string replace -r '^.*/([^/]+?)(?:\.git)?$' '$1' $repo_url)
          end

          set -l dir_name $projects_dir/$project_name

          if not test -d $dir_name
              if test -n "$repo_url"
                  git clone $repo_url $dir_name
                  if test $status -ne 0
                      echo "Failed to clone repository." >&2
                      return 1
                  end
                  echo "Cloned repository to: $dir_name"
              else
                  echo "Project '$project_name' does not exist."
                  echo "Options:"
                  echo "  1) create - Create a new empty project"
                  echo "  2) clone  - Clone a git repository"
                  echo "  3) cancel - Cancel operation"
                  read -l -P "Choose ([1]create/[2]clone/[3]cancel): " action

                  switch $action
                      case 1 create
                          mkdir -p $dir_name
                          echo "Created new project directory: $dir_name"

                      case 2 clone
                          read -l -P "Enter the git repository URL: " repo_url
                          git clone $repo_url $dir_name
                          if test $status -ne 0
                              echo "Failed to clone repository." >&2
                              return 1
                          end
                          echo "Cloned repository to: $dir_name"

                      case 3 cancel
                          echo "Operation cancelled."
                          return 1

                      case '*'
                          echo "Invalid option. Operation cancelled."
                          return 1
                  end
              end
          end

          set -l current_time (date "+%Y-%m-%d %H:%M:%S")

          # Escape commas in project_name and dir_name if they exist
          set project_name (string replace ',' '\\,' $project_name)
          set dir_name (string replace ',' '\\,' $dir_name)

          echo "$project_name,$dir_name,$current_time" >>$projects_file

          cd $dir_name
          echo "Switched to project: $project_name"
        '';
      };
    };

    completions = {
      gi = ''
        function __fish_print_gitignore_list
            if ! set -q __FISH_PRINT_GITIGNORE_LIST
                set -g __FISH_PRINT_GITIGNORE_LIST (curl -sL https://www.toptal.com/developers/gitignore/api/list)
            end
            echo $__FISH_PRINT_GITIGNORE_LIST | string split ","
        end

        complete -xc gi -a '(__fish_print_gitignore_list)'
      '';

      workon = ''
        function __fish_workon_projects
            set -l projects_file (__fish_projects_dir)/.projects
            if test -f $projects_file
                while read -l line
                    set -l parts (string split ',' $line)
                    set -l project_name $parts[1]
                    set -l last_access $parts[3]
                    if test -n "$last_access"
                        echo $project_name\t"Last accessed: $last_access"
                    else
                        echo $project_name
                    end
                end <$projects_file
            end
        end

        complete -c workon -f -a "(__fish_workon_projects)"
      '';
    };
  };
}
