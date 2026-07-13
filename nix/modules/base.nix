# Fundação: nix, locale, rede, usuário. Equivale ao "pós-install básico" do Arch.
{ pkgs, ... }:

{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # GC automático — a /nix/store não cresce pra sempre
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nixpkgs.config.allowUnfree = true; # nvidia, etc. (fase metal)

  time.timeZone = "America/Sao_Paulo";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "br-abnt2";

  networking.networkmanager.enable = true;

  users.users.v1cferr = {
    isNormalUser = true;
    description = "v1cferr";
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.zsh;
  };
  programs.zsh.enable = true;

  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    nano
  ];
}
