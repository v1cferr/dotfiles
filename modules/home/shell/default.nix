# Shell, terminal and command line tools (the dev CLI).
{ ... }:

{
  imports = [
    ./zsh.nix # ~/.zshrc (history plus autosuggest plus syntax highlighting plus aliases)
    ./starship.nix # ~/.config/starship.toml (zsh's prompt)
    ./cli.nix # the modern CLI toolkit (eza/bat/fzf/zoxide/direnv/yazi/tealdeer) plus the zsh integration
    ./kitty.nix # ~/.config/kitty/kitty.conf (Hyprland's default terminal)
    ./tmux.nix # ~/.config/tmux/tmux.conf plus `ct`/`ctw`/`ca`, Claude in sessions the phone can join
    ./claude-code.nix # the package plus the separate accounts (claude-fai/claude-pessoal/claude-pick)
    ./antigravity.nix # Google's agent CLI (`agy`), plus the MCP servers merged into its config
    ./codex.nix # OpenAI's CLI (its declared config is the system layer, modules/nixos/services/codex.nix)
    ./opencode.nix # sst's agent CLI, plus the MCP servers in its generated opencode.json
    ./git.nix # programs.git, hence ~/.gitconfig
    ./ssh.nix # ~/.ssh/config, hence the FAI hosts (workstation/fai-vm) through the VPN
    ./ntfy.nix # the `notify` command, a push to the phone (the ntfy topic comes from sops)
    ./fastfetch # ~/.config/fastfetch/config.jsonc (the system summary)
  ];
}
