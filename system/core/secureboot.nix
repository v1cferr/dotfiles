# ═══════════════════════════════════════════════════════════════════════════
# SECURE BOOT — chaves próprias via sbctl, com o GRUB assinado a cada switch.
#
# POR QUE NÃO O LANZABOOTE (o caminho oficial e 100% declarativo do NixOS): ele é
# systemd-boot-only, e o systemd-boot não consegue listar o Windows daqui, porque
# cada sistema tem a sua ESP em disco separado (ver ./boot.nix). Escolha feita com
# olhos abertos: o dualboot com menu vale mais que a cadeia verificada de ponta a
# ponta, e o motivo é que essa cadeia NÃO É COMPLETA aqui de qualquer jeito —
#
#   ⚠️ O QUE ESTE ARQUIVO DÁ, E O QUE NÃO DÁ. A firmware verifica o GRUB (assinado
#   com a chave desta máquina) e verifica o `bootmgfw.efi` do Windows (assinado
#   pela Microsoft). O GRUB, porém, carrega kernel e initrd SEM verificar nada —
#   e isso não é acidente: é o `--disable-shim-lock` em ./boot.nix, que é
#   OBRIGATÓRIO pra máquina bootar (sem ele o GRUB exige o protocolo do shim, que
#   não existe aqui, e morre em "shim_lock protocol not found" — tanto no NixOS
#   quanto no Windows). Ou seja: isto satisfaz a firmware e o Windows, e barra um
#   bootloader trocado por fora; NÃO barra quem já tenha root e troque o kernel.
#   Quem quiser a cadeia inteira precisa de shim (e aí kernel assinado pela
#   Microsoft) ou do lanzaboote (e aí sem menu e sem tema). Não há terceira porta.
#
# CERTIFICADOS DA MICROSOFT: `enroll-keys -m` é OBRIGATÓRIO. Sem ele, apagar as
# chaves de fábrica derruba junto (a) o Windows, cujo bootloader é assinado pela
# MS, e (b) a option ROM da Arc B580, que também é. Conferido em 02/08/2026 nesta
# máquina: o `db` da BIOS 2803 já traz as DUAS gerações de CA — as de 2011
# (Windows Production PCA / Corporation UEFI CA) e as de 2023 (Windows UEFI CA
# 2023, Microsoft UEFI CA 2023, Option ROM UEFI CA 2023) — e o sbctl 0.18 embute
# as seis. Isso importa AGORA e não em tese: o CA de 2011 expirou em junho/2026 e
# as atualizações novas do Windows vêm assinadas pelo de 2023. Enrolar só o de
# 2011 seria um Windows que boota hoje e para de bootar num Patch Tuesday qualquer.
# (`--firmware-builtin` não serve aqui: o `dbDefault` desta firmware está VAZIO.)
#
# ─── RUNBOOK (o que é manual e por quê) ──────────────────────────────────────
# Enrolar chave exige a firmware em Setup Mode, e Setup Mode só se entra pela BIOS.
# Nenhuma parte disto é automatizável; o que o Nix automatiza é a assinatura.
#
#   0. NO WINDOWS, ANTES DE TUDO: `manage-bde -status`. Se algum volume disser
#      "Protection On", `manage-bde -off C:` e ESPERE terminar a decifragem.
#      Mexer em Secure Boot muda o PCR 7, e o BitLocker responde a isso pedindo a
#      chave de recuperação no boot — que ninguém guardou, porque a conta é local.
#   1. `sudo sbctl create-keys`      (cria /var/lib/sbctl/keys)
#   2. `rebuild`                     (o hook abaixo assina o GRUB)
#   3. BIOS (DEL): Secure Boot → Key Management → **Clear Secure Boot Keys**.
#      Salva e sai (F10). Isso põe a firmware em Setup Mode; o boot segue normal.
#   4. `sudo sbctl enroll-keys -m`   (-m = com os certificados da Microsoft!)
#      `sbctl status` deve mostrar Setup Mode: Disabled.
#   5. BIOS: **Secure Boot → Enabled** (OS Type: Windows UEFI mode). Reboot.
#   6. Conferir: `sbctl status` (Secure Boot ✓) e `sbctl verify` (GRUB assinado).
#
# SE A MÁQUINA NÃO BOOTAR: desligue o Secure Boot na BIOS. Não há tijolo possível
# aqui — a única coisa que a firmware recusa é o binário, e desligar SB a devolve.
#
# ⚠️ `/var/lib/sbctl` É ESTADO CRÍTICO e não está no restic (regra 6 manda estado
# pro backup; este é estado que o backup não cobre). Perder essa pasta = o próximo
# switch não assina o GRUB = máquina não boota com SB ligado. Recuperação: SB off
# na BIOS, refazer os passos 1–5. E é o PRIMEIRO item a declarar quando a
# impermanência entrar (ver ANOTACOES.md), senão o reboot apaga as chaves.
# ═══════════════════════════════════════════════════════════════════════════
{ pkgs, ... }:

let
  # Assina o GRUB depois de todo `nixos-rebuild switch`. Não é paranoia de sobra: o
  # grub-install só reescreve o grubx64.efi quando algo muda (versão do GRUB, ESP,
  # devices), e é EXATAMENTE nesse switch — o que você não previu — que um binário
  # novo e sem assinatura vai pra ESP. Com Secure Boot ligado, isso é uma máquina
  # que não liga, descoberta no reboot seguinte e não no rebuild que a causou.
  signGrub = pkgs.writeShellApplication {
    name = "grub-sbctl-sign";
    runtimeInputs = [ pkgs.sbctl ];
    text = ''
      # Antes do `sbctl create-keys` não existe o que assinar. Sai 0 com AVISO em
      # vez de falhar: senão o PRIMEIRO switch pro GRUB (passo 2 do runbook, quando
      # ainda não há chaves) abortaria a ativação inteira. Com o Secure Boot ainda
      # desligado nesse ponto, GRUB sem assinatura boota normalmente.
      if [ ! -d /var/lib/sbctl/keys ]; then
        echo "sbctl: sem chaves em /var/lib/sbctl/keys — GRUB NÃO assinado." >&2
        echo "       Rode 'sudo sbctl create-keys' e refaça o rebuild." >&2
        exit 0
      fi

      # Glob em vez do caminho literal: o bootloaderId default é montado pelo módulo
      # como distroName + mountpoint da ESP com '/'→'-' (= "NixOS-boot"), e depender
      # dessa string é depender de detalhe interno do nixpkgs. Varrer a ESP não corre
      # risco de assinar binário alheio — a ESP do Windows é OUTRO disco, nunca /boot.
      for efi in /boot/EFI/*/grubx64.efi /boot/EFI/BOOT/BOOTX64.EFI; do
        [ -e "$efi" ] || continue
        # `sbctl sign` é IDEMPOTENTE (cmd/sbctl/sign.go:88 — já assinado devolve 0),
        # então rodar em todo switch é barato e não mascara falha real: qualquer
        # outro erro sai != 0 e o `set -e` derruba a ativação, que é o que se quer.
        # -s grava no db do sbctl, pra `sbctl verify`/`sign-all` enxergarem o arquivo.
        sbctl sign -s "$efi"
      done
    '';
  };
in
{
  # Ferramenta do runbook acima (create-keys / enroll-keys / status / verify).
  environment.systemPackages = [ pkgs.sbctl ];

  # Roda no fim do install-grub.sh, depois das entradas do menu (grub.nix:837).
  boot.loader.grub.extraInstallCommands = "${signGrub}/bin/grub-sbctl-sign";
}
