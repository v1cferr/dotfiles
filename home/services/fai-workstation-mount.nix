# Workstation da FAI montada como pasta local (~/FAI-workstation) via rclone SFTP + cache
# VFS → aparece no Dolphin como pasta normal, rápida (cache de leitura/escrita, relê do
# disco). Sobe SÓ quando a VPN FAI conecta (o `vpn connect fai` inicia o mount; disconnect
# derruba) — o host 200.136.209.229 só existe pela VPN, então nada de mount fantasma/stale
# no boot (o SSHFS travaria o Dolphin nesse cenário; o rclone falha limpo e reconecta).
# SFTP por key_file (a chave SSH que já existe) → ZERO segredo no nix.
{ ... }:

{
  programs.rclone = {
    enable = true;
    remotes.faiws = {
      # rclone.conf gerado pelo módulo; só caminhos/host aqui (nenhum segredo).
      config = {
        type = "sftp";
        host = "200.136.209.229"; # workstation (alcançável só via VPN FAI)
        user = "v1cferr";
        key_file = "/home/v1cferr/.ssh/id_ed25519"; # chave existente (estado → backup)
        known_hosts_file = "/home/v1cferr/.ssh/known_hosts"; # workstation já confiada
      };
      mounts."/" = {
        # "/" = raiz inteira da workstation (não só o home). O user v1cferr vê o que tem
        # permissão de ler; o resto aparece mas fica inacessível (normal p/ não-root).
        enable = true;
        autoMount = false; # NÃO monta no boot — o `vpn connect fai` sobe (VPN-gated)
        mountPoint = "/home/v1cferr/FAI-workstation";
        options = {
          # "writes": LEITURAS passam direto (streaming, NÃO acumulam em disco) — só o que
          # você escreve/copia é cacheado até subir. Disco fica enxuto. (Troque p/ "full"
          # se quiser velocidade máxima de reabrir arquivos, ao custo de encher o cache.)
          vfs-cache-mode = "writes";
          vfs-cache-max-age = "6h"; # evicta o cache de escrita rápido
          vfs-cache-max-size = "2G"; # teto baixo do cache em disco (~/.cache/rclone)
          dir-cache-time = "5m"; # listagem cacheada 5min → navegar fica RÁPIDO (F5 recarrega)
          buffer-size = "8M"; # RAM de read-ahead por arquivo aberto — baixo de propósito
          timeout = "30s"; # timeout de I/O (não pendura eterno se a VPN cair)
          contimeout = "15s"; # timeout de conexão
        };
      };
    };
  };

  # A VPN sobe assíncrona (~10s até o túnel/rotas). Sem isto o systemd desistiria após 5
  # falhas rápidas (StartLimit) antes do host ficar alcançável. Retry a cada 10s até
  # conectar — como o `vpn connect fai` dá o start e o `disconnect` dá o stop, não fica em
  # loop eterno quando a VPN está intencionalmente desligada.
  systemd.user.services."rclone-mount:.@faiws" = {
    Unit.StartLimitIntervalSec = 0;
    Service.RestartSec = 10;
  };
}
