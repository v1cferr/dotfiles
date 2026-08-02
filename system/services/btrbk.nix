# ═══════════════════════════════════════════════════════════════════════════
# SNAPSHOTS LOCAIS (btrbk) — o "desfazer" de minutos do @home.
#
# NÃO É BACKUP, e a distinção importa: snapshot mora no MESMO disco que o dado.
# Kingston morreu → morreram os snapshots junto. Quem cobre isso é o restic
# (restic.nix), off-disk no Seagate + Drive. Os dois existem porque respondem a
# perguntas diferentes:
#   • restic → "o disco morreu / a casa pegou fogo"     (diário, off-disk, cifrado)
#   • btrbk  → "sobrescrevi o arquivo há 20 minutos"    (horário, instantâneo, local)
# O restic sozinho deixa um buraco de até 24 h e um restore que leva minutos; o
# btrbk fecha esse buraco por ~zero custo, porque snapshot de CoW não copia nada:
# só passa a ocupar espaço na MEDIDA em que o dado original diverge.
#
# SÓ @home. A raiz fica de fora de propósito: no NixOS o rollback do sistema já é
# a lista de gerações do GRUB, e snapshot de `/` nem pegaria o /nix (subvolume
# separado — snapshot não desce pra subvolume aninhado). Seria ruído sem ganho.
#
# PRÉ-REQUISITO: o subvolume @snapshots montado em /.snapshots (ver disko.nix).
# Num sistema já instalado ele é criado à mão UMA vez — o comando está lá.
#
# Restaurar um arquivo é `cp` de /.snapshots/home.<timestamp>/... — snapshot é
# só um diretório navegável. Reverter o @home INTEIRO é operação manual e
# consciente (trocar o subvolume), nunca automática.
# ═══════════════════════════════════════════════════════════════════════════
{ config, lib, ... }:

lib.mkIf config.my.services.btrbk {
  # Mesma trava do restic (restic.nix): sem o /.snapshots montado, o btrbk
  # escreveria dentro de `@` — o único lugar onde a impermanência apaga tudo,
  # e sem o dono perceber. RequiresMountsFor barra isso.
  systemd.services.btrbk-home.unitConfig.RequiresMountsFor = "/.snapshots";

  # (Persistent=true no timer — importante nesta máquina, que reinicia muito — já
  # vem do módulo do btrbk; não precisa repetir aqui.)

  services.btrbk.instances.home = {
    onCalendar = "hourly";
    settings = {
      timestamp_format = "long"; # inclui hora:minuto — snapshot horário precisa

      # "onchange": nada escrito desde o último snapshot → não cria um novo. Sem
      # isto, a máquina ligada e ociosa geraria 24 snapshots idênticos por dia e
      # empurraria os úteis pra fora da retenção.
      snapshot_create = "onchange";

      # 48h/7d/4w ≈ 2 dias de granularidade fina + um mês de rede de segurança.
      # Casa com o restic (--keep-daily 7 --keep-weekly 4): o btrbk cobre o que
      # é curto demais pro backup diário alcançar.
      snapshot_preserve = "48h 7d 4w";
      snapshot_preserve_min = "latest"; # nunca fica sem NENHUM snapshot

      # Forma de CAMINHO ABSOLUTO (sem seção `volume`). A outra forma do btrbk
      # — `volume <pool>` + subvolume relativo — pressupõe o subvolid=5 montado
      # num diretório, e montar o topo permanentemente faria cada subvolume
      # aparecer DUAS vezes na árvore (confunde du/find e qualquer varredura).
      # Com caminho absoluto o btrbk resolve /home direto, que é o que queremos.
      snapshot_dir = "/.snapshots";
      subvolume."/home" = { }; # /home = subvolume @home
    };
  };
}
