# home-manager: consome os MESMOS arquivos que o stow entrega no Arch.
# Um repo, dois consumidores (ver NIXOS-MIGRATION.md §5).
{ config, pkgs, ... }:

let
  # Raiz do repo (vai pra /nix/store na avaliação — puro, funciona na VM)
  dotfiles = ../..;
in
{
  home.username = "v1cferr";
  home.homeDirectory = "/home/v1cferr";

  programs.home-manager.enable = true;

  # ── Configs cruas do repo (read-only via store) ──────────────────────────
  xdg.configFile."hypr".source = "${dotfiles}/hypr/.config/hypr";
  xdg.configFile."quickshell".source = "${dotfiles}/quickshell/.config/quickshell";
  xdg.configFile."kitty".source = "${dotfiles}/kitty/.config/kitty";

  # No METAL, p/ edição quente (hot-reload do QML sem rebuild), trocar por:
  # xdg.configFile."quickshell".source = config.lib.file.mkOutOfStoreSymlink
  #   "${config.home.homeDirectory}/dotfiles/quickshell/.config/quickshell";
  # (exige o repo clonado em ~/dotfiles; vale p/ hypr também)

  home.packages = with pkgs; [
    fastfetch
    btop
    eza
    fzf
  ];

  # NÃO mudar depois do primeiro switch
  home.stateVersion = "25.11";
}
