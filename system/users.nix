# ═══════════════════════════════════════════════════════════════════════════
# USUÁRIO & SHELL — zsh como shell de login + a conta v1cferr (identidade).
# ═══════════════════════════════════════════════════════════════════════════
{ config, pkgs, ... }:

{
  # ── Shell: zsh ──────────────────────────────────────────────────────────────
  # O NixOS exige o enable system-wide pra usar zsh como shell de login: registra
  # em /etc/shells, cria o /etc/zshrc e liga completion global. A config interativa
  # (histórico/aliases/plugins) e o prompt (starship) vivem no home/ (zsh.nix).
  programs.zsh.enable = true;

  # ── Usuário (capacidade declarada; senha/chaves = "quem sou eu") ────────────
  # Hash da senha via sops (fora do git). Chaves públicas SSH são públicas — ok.
  users.users.v1cferr = {
    isNormalUser = true;
    description = "Victor";
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.zsh; # shell de login = zsh (config interativa em home/zsh.nix)
    hashedPasswordFile = config.sops.secrets.v1cferr_password_hash.path;
    openssh.authorizedKeys.keys = [
      # chave que entra no Arch hoje (~/.ssh/authorized_keys)
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKPvFX6AAslYtCXeUnNmSIKL4GESHvgO+irlnJ5+2ltD dev.victorferreira@gmail.com"
      # chave local do Arch/Kingston — pra hop Arch -> NixOS
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINRHYth5yugzhdulstjLPJAqHuzXE6j/EVl7dHcWKIUI dev.victorferreira@gmail.com"
    ];
  };
  security.sudo.wheelNeedsPassword = true;
}
