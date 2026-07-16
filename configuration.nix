# ════════════════════════════════════════════════════════════════════════════
# NixOS do zero — v1cferr
# Este arquivo começa vazio DE PROPÓSITO: cada linha será escrita à mão (README.md).
# ════════════════════════════════════════════════════════════════════════════
#
# Kit anti-cegueira sugerido pro 1º nixos-rebuild (escrever, não colar!):
#
#   networking.networkmanager.enable  → internet
#   services.openssh.enable           → configurar via SSH sentado no Arch
#   users.users.v1cferr               → isNormalUser + wheel + senha
#   environment.systemPackages        → git + editor (mínimo pra não ficar de mãos atadas)
#   time.timeZone                     → America/Sao_Paulo
#   console.keyMap                    → br-abnt2
#
# Referências:
#   - Opções: https://search.nixos.org/options
#   - Gabarito testado (VM): git checkout nix-flake-skeleton -- nix/
#   - Regra de ouro: git add antes de todo rebuild (flake não vê untracked)
#
{ config, pkgs, ... }:

{
}
