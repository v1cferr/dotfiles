# Shell, terminal e ferramentas de linha de comando (dev-cli).
{ ... }:

{
  imports = [
    ./zsh.nix # ~/.zshrc (histórico + autosuggest + syntax highlight + aliases)
    ./starship.nix # ~/.config/starship.toml (prompt do zsh)
    ./cli.nix # toolkit CLI moderno (eza/bat/fzf/zoxide/direnv/yazi/tealdeer) + integração zsh
    ./tools.nix # CLIs sem config própria (gh, bitwarden-cli, fastfetch, claude-code, yt-dlp)
    ./kitty.nix # ~/.config/kitty/kitty.conf (terminal default do Hyprland)
    ./git.nix # programs.git → ~/.gitconfig
  ];
}
