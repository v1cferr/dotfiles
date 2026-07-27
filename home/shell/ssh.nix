# Config SSH do cliente (~/.ssh/config declarativo): hosts da FAI via a VPN split-tunnel.
# A chave privada (~/.ssh/id_ed25519) é ESTADO/segredo → vem pelo backup, não pelo Nix (regra 6).
{ ... }:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false; # o bloco "*" com defaults antigos foi deprecado; o OpenSSH já traz sanos

    # Ambos vivem na sub-rede 200.136.209.128/25, roteada pela `vpn connect fai`.
    settings = {
      # Workstation da FAI (mesma máquina do Wake-on-LAN).
      workstation = {
        HostName = "200.136.209.229";
        User = "v1cferr";
        Port = 22;
        IdentityFile = "~/.ssh/id_ed25519";
        SetEnv = { TERM = "xterm-256color"; }; # cores certas no terminal remoto
      };
      # VM de apoio na FAI.
      fai-vm = {
        HostName = "200.136.209.248";
        User = "v1cferr";
        Port = 22;
        SetEnv = { TERM = "xterm-256color"; };
      };
    };
  };
}
