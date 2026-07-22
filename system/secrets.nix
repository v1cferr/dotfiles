# ═══════════════════════════════════════════════════════════════════════════
# SEGREDOS AUTOMÁTICOS — Bitwarden como fonte da verdade, sops como cofre.
#
# O índice PÚBLICO secrets/bitwarden-secrets.json mapeia nome-no-sops -> item-no-
# Bitwarden (não é segredo; vai no git). A partir dele:
#   1. o nix GERA os `sops.secrets.<nome>` sozinho (nunca mais declarar à mão);
#   2. o comando `sync-secrets` puxa os valores do Bitwarden e grava CIFRADO no
#      secrets.yaml (via sops set) — o rebuild continua PURO (sem --impure).
#
# Adicionar segredo: cadastra no Bitwarden -> +1 linha no JSON -> `sync-secrets`
# -> `nixos-rebuild switch`. Segredos que NÃO vêm do Bitwarden (ex.: o hash de
# senha do usuário) seguem declarados à mão no default.nix.
# ═══════════════════════════════════════════════════════════════════════════
{ pkgs, lib, ... }:

let
  # Índice público: { "<nome-no-sops>" = "<item-no-Bitwarden>"; ... }
  bwMap = builtins.fromJSON (builtins.readFile ../secrets/bitwarden-secrets.json);

  sync-secrets = pkgs.writeShellApplication {
    name = "sync-secrets";
    runtimeInputs = with pkgs; [ bitwarden-cli jq sops git ];
    text = builtins.readFile ../scripts/sync-secrets.sh; # bash à parte = shellcheck no build
  };
in
{
  # ── Base do sops-nix ───────────────────────────────────────────────────────
  # secrets/secrets.yaml: cifrado, versionado, ilegível sem a chave. Decriptado em
  # runtime pra /run/secrets*. A chave age (/var/lib/sops-nix/key.txt) fica FORA do
  # git — é o que se leva no cutover. Editar: nix shell nixpkgs#sops -c sops secrets/secrets.yaml
  sops.defaultSopsFile = ../secrets/secrets.yaml;
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";

  # Gera um sops.secrets.<nome> = {} pra cada entrada do índice (Bitwarden), e
  # mescla (//) os segredos que NÃO vêm do Bitwarden (declarados à mão).
  sops.secrets = (lib.mapAttrs (_key: _item: { }) bwMap) // {
    v1cferr_password_hash.neededForUsers = true; # hash da senha: precisa cedo (usuário)
    cloudflare_ddns_token = { };
  };

  environment.systemPackages = [ sync-secrets ];
}
