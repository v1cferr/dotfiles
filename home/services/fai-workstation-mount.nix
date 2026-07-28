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
      mounts."/home/v1cferr" = {
        enable = true;
        autoMount = false; # NÃO monta no boot — o `vpn connect fai` sobe (VPN-gated)
        mountPoint = "/home/v1cferr/FAI-workstation";
        options = {
          vfs-cache-mode = "full"; # cache leitura+escrita (rápido; já é o default do módulo)
          vfs-cache-max-age = "168h"; # mantém no cache por 1 semana
          vfs-cache-max-size = "10G"; # teto do cache local
          dir-cache-time = "30s"; # revalida listagem rápido (arquivo novo aparece logo)
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
  systemd.user.services."rclone-mount:.home.v1cferr@faiws" = {
    Unit.StartLimitIntervalSec = 0;
    Service.RestartSec = 10;
  };
}
