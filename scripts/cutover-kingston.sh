#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# Cutover SanDisk → Kingston, guiado. Roda NO LIVE USB (NixOS minimal), como root.
#
#   bash /mnt/sd/home/v1cferr/Projects/GitHub/v1cferr/dotfiles/scripts/cutover-kingston.sh
#
# É o MIGRACAO-KINGSTON.md executável: mesmas fases, mesma ordem, cada uma
# anunciando o que vai fazer e pedindo confirmação. Existe porque no console do
# instalador não há mouse nem clipboard — digitar 40 comandos à mão de madrugada é
# onde se erra um device e se formata o disco errado.
#
# EXCEÇÃO CONSCIENTE À REGRA 7 (sem .sh solto): a regra existe pra que o shellcheck
# rode no build do Nix. Este script roda ANTES de existir NixOS na máquina — não há
# build pra hospedá-lo. Fica solto, e a validação é manual:
#     nix shell nixpkgs#shellcheck -c shellcheck scripts/cutover-kingston.sh
# Mesma natureza (e mesmo fim de vida) do cutover-sandisk.sh, removido após uso.
#
# SEGURO POR CONSTRUÇÃO: idempotente (repetir pula o que já foi feito), toda etapa
# confirma antes, e a única destrutiva exige digitar uma palavra inteira. Se algo
# falhar, `set -e` para na hora — o SanDisk continua bootável e nada se perdeu.
# ═══════════════════════════════════════════════════════════════════════════
set -euo pipefail

# ── Constantes desta máquina (MOBO ASUS EX-B560M-V5) ───────────────────────
KINGSTON_ID="/dev/disk/by-id/nvme-KINGSTON_SKC3000S1024G_50026B7686B3D2F6"
SANDISK_UUID="d0392422-6a6c-4c36-8ff4-e6eda25ae487"
SD="/mnt/sd"                                   # onde o SanDisk é montado
REPO="$SD/home/v1cferr/Projects/GitHub/v1cferr/dotfiles"
GCROOT="$SD/home/v1cferr/kingston-system"      # symlink p/ a closure pré-construída
HOST="nixos-kingston"

# Estado de serviço que atravessa. `nixos` é o mais importante e o menos óbvio:
# guarda uid-map/gid-map, e sem ele serviço nasce com outro UID e perde acesso
# aos arquivos que ele mesmo criou.
VARLIB=(nixos NetworkManager AccountsService bluetooth fail2ban
        qBittorrent cloudflare-dyndns lightdm-data)

# ── Saída ──────────────────────────────────────────────────────────────────
titulo() { printf '\n\033[1;36m══ %s\033[0m\n' "$*"; }
ok()     { printf '  \033[32m✓\033[0m %s\n' "$*"; }
aviso()  { printf '  \033[33m!\033[0m %s\n' "$*"; }
erro()   { printf '\n\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

confirmar() {
  local r
  read -rp "  → $1 [s/N] " r
  [[ "$r" == "s" || "$r" == "S" ]]
}

# ── Pré-condições ──────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || erro "Rode como root: sudo -i"

titulo "Cutover SanDisk → Kingston"
cat <<TXT
  Destino : $KINGSTON_ID
  Origem  : SanDisk UUID $SANDISK_UUID
  Host    : $HOST

  O SanDisk NÃO é tocado por este script — segue bootável até o fim.
  Se algo der errado, reinicie e escolha o SanDisk no menu da firmware (F8).
TXT
confirmar "Começar?" || exit 0

# ── 1. Rede ────────────────────────────────────────────────────────────────
titulo "1/7  Rede"
if ping -c1 -W5 cache.nixos.org >/dev/null 2>&1; then
  ok "cache.nixos.org alcançável"
else
  aviso "sem rede — o disko precisa baixar. Tente: systemctl restart dhcpcd"
  confirmar "Seguir mesmo assim?" || exit 1
fi

# ── 2. Montar o SanDisk ────────────────────────────────────────────────────
titulo "2/7  Montar o SanDisk em $SD"
if mountpoint -q "$SD"; then
  ok "já montado"
else
  mkdir -p "$SD"
  mount "/dev/disk/by-uuid/$SANDISK_UUID" "$SD"
  ok "montado"
fi
# Marcadores: se faltarem, o disco montado não é o que esperamos.
[[ -f "$REPO/flake.nix" ]]            || erro "não achei $REPO/flake.nix — disco errado?"
[[ -f "$SD/var/lib/sops-nix/key.txt" ]] || erro "não achei a chave age no SanDisk"
ok "repo e chave age no lugar"

# ── 3. Formatar o Kingston  ⚠️ DESTRUTIVO ──────────────────────────────────
titulo "3/7  Formatar o Kingston (disko)"
if findmnt -no FSTYPE /mnt 2>/dev/null | grep -q btrfs; then
  ok "/mnt já é btrfs — disko já rodou, pulando"
else
  cat <<TXT
  Isto APAGA o Kingston inteiro e cria: ESP 1G + btrfs
  com os subvolumes @ @home @nix @persist @log @swap.

  O home do Arch que está nele só existe nos dois backups restic.
  Confirme que a Fase 0.1 do runbook passou ANTES de seguir.
TXT
  read -rp "  → Digite FORMATAR para confirmar: " r
  [[ "$r" == "FORMATAR" ]] || erro "cancelado"

  nix --extra-experimental-features 'nix-command flakes' \
    run github:nix-community/disko -- \
    --mode destroy,format,mount --flake "path:$REPO#$HOST"
  ok "disko concluído"
fi

findmnt -no FSTYPE /mnt | grep -q btrfs || erro "/mnt não é btrfs — disko falhou"
for m in /mnt/boot /mnt/home /mnt/nix /mnt/persist /mnt/var/log /mnt/swap; do
  mountpoint -q "$m" || erro "$m não está montado — layout incompleto"
done
ok "todos os subvolumes montados"

# ── 4. Chave age  ⚠️ NÃO PULE ──────────────────────────────────────────────
titulo "4/7  Chave age (sops)"
# Sem isto o v1cferr_password_hash (neededForUsers) não decripta e o usuário
# nasce SEM SENHA — você se tranca fora do sistema recém-instalado.
if [[ -f /mnt/var/lib/sops-nix/key.txt ]]; then
  ok "já copiada"
else
  install -Dm600 "$SD/var/lib/sops-nix/key.txt" /mnt/var/lib/sops-nix/key.txt
  ok "copiada com modo 600"
fi
grep -q '^AGE-SECRET-KEY-1' /mnt/var/lib/sops-nix/key.txt \
  || erro "a chave não parece uma chave age"
ok "conteúdo confere"

# ── 5. Instalar ────────────────────────────────────────────────────────────
titulo "5/7  Instalar o sistema"
if [[ -e /mnt/nix/var/nix/profiles/system ]]; then
  ok "sistema já instalado, pulando"
else
  [[ -L "$GCROOT" ]] || erro "closure pré-construída não achada em $GCROOT (ver Fase 0.2)"
  SYS="$(readlink -f "$GCROOT")"
  echo "  closure: $SYS"

  # --system instala closure PRONTA e não avalia flake nenhum. Isso evita o input
  # duo-streak-daemon, que é git+ssh privado e derrubaria um --flake aqui.
  nix --extra-experimental-features 'nix-command flakes' \
    copy --no-check-sigs --from "local?root=$SD" --to /mnt "$SYS"
  ok "closure copiada do SanDisk"

  nixos-install --root /mnt --system "$SYS" --no-root-passwd
  ok "nixos-install concluído"
fi

# ── 6. Levar o estado ──────────────────────────────────────────────────────
titulo "6/7  Estado não-declarativo"
command -v rsync >/dev/null || erro "rsync ausente. Rode primeiro:
    nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#rsync
  e chame este script de novo (ele pula o que já foi feito)."

if confirmar "Copiar o /home? (~403 G, 15-25 min)"; then
  rsync -aHAX --info=progress2 "$SD/home/" /mnt/home/
  ok "/home copiado"
fi

if confirmar "Copiar o estado de serviço de /var/lib?"; then
  mkdir -p /mnt/var/lib
  for d in "${VARLIB[@]}"; do
    [[ -e "$SD/var/lib/$d" ]] && rsync -aHAX "$SD/var/lib/$d" /mnt/var/lib/ && echo "    $d"
  done
  ok "/var/lib copiado"
fi

if confirmar "Copiar chaves de host SSH e conexões do NetworkManager?"; then
  # Glob que não casa vira literal e derruba o cp sob `set -e` — daí o teste antes.
  # nullglob não serve: `cp` sem origem também falha.
  if compgen -G "$SD/etc/ssh/ssh_host_*" >/dev/null; then
    mkdir -p /mnt/etc/ssh
    cp -a "$SD"/etc/ssh/ssh_host_* /mnt/etc/ssh/
    ok "chaves de host SSH copiadas (clientes não vão acusar host trocado)"
  else
    aviso "nenhuma chave de host encontrada no SanDisk — pulando"
  fi

  if [[ -d "$SD/etc/NetworkManager/system-connections" ]]; then
    mkdir -p /mnt/etc/NetworkManager
    rsync -aHAX "$SD/etc/NetworkManager/system-connections" /mnt/etc/NetworkManager/
    ok "perfis de rede copiados (inclui o segredo da VPN da UFSCar)"
  else
    aviso "system-connections não encontrado — pulando"
  fi
fi

# O Tailscale registra pelo hostname, que muda. Herdar o node key mantém IP e ACLs,
# mas DOIS sistemas com a mesma chave brigam — só faça se não for ligar os dois.
if confirmar "Herdar a identidade Tailscale? (N = entra como nó novo, recomendado)"; then
  if [[ -d "$SD/var/lib/tailscale" ]]; then
    rsync -aHAX "$SD/var/lib/tailscale" /mnt/var/lib/
    ok "node key herdado — NÃO ligue os dois sistemas ao mesmo tempo"
  else
    aviso "/var/lib/tailscale não existe no SanDisk — vai entrar como nó novo"
  fi
else
  ok "vai entrar como nó novo — apague o nixos-sandisk no admin depois"
fi

# ── 7. Fim ─────────────────────────────────────────────────────────────────
titulo "7/7  Pronto para reiniciar"
cat <<TXT
  Rode agora:
      umount -R $SD /mnt
      reboot

  Tire o pendrive e escolha o Kingston no menu (F8).
  A validação do primeiro boot está na Fase 7 do MIGRACAO-KINGSTON.md.
TXT
