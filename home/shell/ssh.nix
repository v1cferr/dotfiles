# Config SSH do cliente (~/.ssh/config declarativo): hosts da FAI via a VPN split-tunnel.
# A chave privada (~/.ssh/id_ed25519) é ESTADO/segredo → vem pelo backup, não pelo Nix (regra 6).
{ config, ... }:

let
  ws = config.my.fai.workstation; # SSOT: home/net/fai-workstation.nix (regra 11)

  # Resiliência p/ sessões longas sobre o túnel SonicWall (buraco de rota transitório com o
  # ppp0 vivo). Tolerar o buraco em vez de derrubar a sessão — mas TUDO dimensionado p/ caber
  # no orçamento do VS Code Remote-SSH, que aborta com "Connecting with SSH timed out" aos
  # 17 s FIXOS (log da extensão: "Using connect timeout of 17 seconds").
  faiResilience = {
    ServerAliveInterval = 15; # keepalive cifrado a cada 15s: segura a sessão ociosa no SonicWall
    # 8 falhas (~2 min) de tolerância. Já foi 20 (~5 min) e era CONTRAPRODUCENTE: o master
    # multiplexado ficava travado num túnel morto todo esse tempo, e cada nova conexão
    # grudava nele e pendurava junto ("mux_client_request_session: Broken pipe" no log do
    # VS Code). 2 min ainda atravessa blip; queda real morre rápido e a extensão reconecta.
    ServerAliveCountMax = 8;
    TCPKeepAlive = "no"; # keepalive do kernel derruba antes do prazo acima; quem manda é o do SSH
    ControlMaster = "auto"; # Remote-SSH abre várias conexões → multiplexa tudo num TCP só
    ControlPath = "~/.ssh/cm-%r@%h:%p"; # socket do master (por usuário/host/porta)
    ControlPersist = "10m"; # master sobrevive 10 min ao último canal: reabrir vira instantâneo
    # 7×2 = 14 s de pior caso, DENTRO dos 17 s do Remote-SSH. Antes era 15×3 = 45 s: o VS Code
    # desistia no meio da 2ª tentativa e reportava timeout mesmo com o host prestes a responder.
    ConnectTimeout = 7;
    ConnectionAttempts = 2; # VPN recém-subida costuma recusar a 1ª tentativa
  };
  # Master travado num túnel que morreu? `ssh -O exit workstation` mata o socket na hora.
in
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false; # o bloco "*" com defaults antigos foi deprecado; o OpenSSH já traz sanos

    # Ambos vivem na sub-rede 200.136.209.128/25, roteada pela `vpn connect fai`.
    settings = {
      # Workstation da FAI (mesma máquina do `wake-workstation`; host/MAC vêm da SSOT).
      workstation = faiResilience // {
        HostName = ws.host;
        User = ws.user;
        Port = 22;
        IdentityFile = "~/.ssh/id_ed25519";
        SetEnv = {
          TERM = "xterm-256color";
        }; # cores certas no terminal remoto
      };
      # VM de apoio na FAI.
      fai-vm = faiResilience // {
        HostName = "200.136.209.248";
        User = "v1cferr";
        Port = 22;
        SetEnv = {
          TERM = "xterm-256color";
        };
      };
    };
  };
}
