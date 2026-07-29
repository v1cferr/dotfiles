# Config SSH do cliente (~/.ssh/config declarativo): hosts da FAI via a VPN split-tunnel.
# A chave privada (~/.ssh/id_ed25519) é ESTADO/segredo → vem pelo backup, não pelo Nix (regra 6).
{ ... }:

let
  # Resiliência p/ sessões longas sobre o túnel SonicWall (VS Code Remote-SSH sofre com
  # buraco de rota transitório: já medimos ~6 min de blackhole só p/ a workstation, com
  # o ppp0 vivo). A ideia é TOLERAR o buraco em vez de derrubar a sessão e reconectar.
  faiResilience = {
    ServerAliveInterval = 15; # keepalive cifrado a cada 15s: segura a sessão ociosa no SonicWall
    ServerAliveCountMax = 20; # só desiste após 20 falhas (~5 min) — atravessa o blackhole sem cair
    TCPKeepAlive = "no"; # keepalive do kernel derruba antes do prazo acima; quem manda é o do SSH
    ControlMaster = "auto"; # Remote-SSH abre várias conexões → multiplexa tudo num TCP só
    ControlPath = "~/.ssh/cm-%r@%h:%p"; # socket do master (por usuário/host/porta)
    ControlPersist = "10m"; # master sobrevive 10 min ao último canal: reabrir vira instantâneo
    ConnectTimeout = 15; # não pendura eterno quando o túnel está fora do ar
    ConnectionAttempts = 3; # VPN recém-subida costuma recusar a 1ª tentativa
  };
in
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false; # o bloco "*" com defaults antigos foi deprecado; o OpenSSH já traz sanos

    # Ambos vivem na sub-rede 200.136.209.128/25, roteada pela `vpn connect fai`.
    settings = {
      # Workstation da FAI (mesma máquina do Wake-on-LAN; MAC 8c:86:dd:61:22:12, enp7s0).
      workstation = faiResilience // {
        HostName = "200.136.209.229";
        User = "v1cferr";
        Port = 22;
        IdentityFile = "~/.ssh/id_ed25519";
        SetEnv = { TERM = "xterm-256color"; }; # cores certas no terminal remoto
      };
      # VM de apoio na FAI.
      fai-vm = faiResilience // {
        HostName = "200.136.209.248";
        User = "v1cferr";
        Port = 22;
        SetEnv = { TERM = "xterm-256color"; };
      };
    };
  };
}
