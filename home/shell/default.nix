# Shell, terminal and command line tools (the dev CLI).
{ ... }:

{
  imports = [
    ./zsh.nix # ~/.zshrc (history plus autosuggest plus syntax highlighting plus aliases)
    ./starship.nix # ~/.config/starship.toml (zsh's prompt)
    ./cli.nix # the modern CLI toolkit (eza/bat/fzf/zoxide/direnv/yazi/tealdeer) plus the zsh integration
    ./kitty.nix # ~/.config/kitty/kitty.conf (Hyprland's default terminal)
    ./claude-code.nix # the package plus the separate accounts (claude-fai/claude-pessoal/claude-pick)
    ./git.nix # programs.git, hence ~/.gitconfig
    ./ssh.nix # ~/.ssh/config, hence the FAI hosts (workstation/fai-vm) through the VPN
    ./ntfy.nix # the `notify` command, a push to the phone (the ntfy topic comes from sops)
    ./fastfetch.nix # ~/.config/fastfetch/config.jsonc (the system summary)
  ];
}
