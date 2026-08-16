# The starship prompt (~/.config/starship.toml). The zsh integration is injected automatically.
# Icons come from the Nerd Font declared in system/hardware/fonts.nix.
{ ... }:

{
  programs.starship = {
    enable = true;
    settings = {
      add_newline = true; # a blank line before every prompt (visual breathing room)

      # A 2-line prompt: the info on top, the typing symbol below.
      format = "$directory$git_branch$git_status$cmd_duration$line_break$character";

      # The prompt's symbol: a green ❯ when the last command succeeded, red if it failed.
      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
      };

      # The current path: truncated at 3 levels, bold blue.
      directory = {
        truncation_length = 3;
        truncate_to_repo = true; # inside a repo, it shows from that repo's root
        style = "bold blue";
      };

      # Git: the branch plus the state (modified/staged files and so on).
      git_branch.style = "bold purple";
      git_status.style = "bold yellow";

      # It shows how long the command took when it goes past 2s (useful for builds/rebuilds).
      cmd_duration = {
        min_time = 2000;
        format = "[took $duration]($style) ";
        style = "italic yellow";
      };
    };
  };
}
