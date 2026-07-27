# Shell, terminal e ferramentas de linha de comando (dev-cli).
{ ... }:

{
  imports = [
    ./zsh.nix # ~/.zshrc (histórico + autosuggest + syntax highlight + aliases)
    ./starship.nix # ~/.config/starship.toml (prompt do zsh)
    ./cli.nix # toolkit CLI moderno (eza/bat/fzf/zoxide/direnv/yazi/tealdeer) + integração zsh
    ./kitty.nix # ~/.config/kitty/kitty.conf (terminal default do Hyprland)
    ./git.nix # programs.git → ~/.gitconfig
    ./ssh.nix # ~/.ssh/config → hosts da FAI (workstation/fai-vm) via a VPN
  ];
}
