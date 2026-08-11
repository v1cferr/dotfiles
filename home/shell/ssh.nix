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
      # Roteador de casa (OpenWrt 25.12 / BusyBox). `ssh router`.
      #
      # SEM `faiResilience`: aquilo dimensiona keepalive e multiplexação pro túnel
      # SonicWall e pro orçamento de 17s do Remote-SSH. Aqui é um salto de LAN com
      # <1ms — herdar aquilo seria carga cultuada, não configuração.
      #
      # IP literal e não opção `my.*`: é o ÚNICO lugar do repo que cita o endereço
      # do gateway (o Caddy usa a faixa /24, não o .1). Literal solitário não
      # dispara a regra 11 — mesma justificativa que o domain.nix registra.
      #
      # ⚠️ O servidor é DROPBEAR, não OpenSSH: aceita ed25519, mas atualização de
      # firmware REGENERA a host key e o próximo `ssh router` aborta com "REMOTE
      # HOST IDENTIFICATION HAS CHANGED". Aí é `ssh-keygen -R 192.168.1.1` e
      # reaceitar — não é ataque, é o flash.
      #
      # ⚠️ authorized_keys VIVE NO ROTEADOR, fora do alcance do Nix (OpenWrt não é
      # NixOS). Isto aqui declara só o LADO CLIENTE. Instalar a chave é passo
      # manual, uma vez por reflash:
      #   ssh-copy-id -i ~/.ssh/id_ed25519.pub v1cferr@192.168.1.1
      # Sobrevive a `sysupgrade` com "keep settings"; reflash limpo exige repetir.
      router = {
        HostName = "192.168.1.1";
        User = "v1cferr";
        Port = 22;
        IdentityFile = "~/.ssh/id_ed25519";
        SetEnv = {
          TERM = "xterm-256color";
        };
      };

      # PC do irmão, na LAN de casa (`ssh cesar` — CESAR é o hostname da máquina).
      #
      # É WINDOWS 11 com OpenSSH_for_Windows_9.5, e é daí que vêm todas as pegadinhas:
      #
      # ⚠️ Sem `SetEnv TERM`: o shell padrão do sshd do Windows é o **cmd.exe**, que não
      # lê TERM — e o sshd de lá não traz `AcceptEnv`, então a variável seria descartada
      # no servidor de qualquer jeito. Mandar mesmo assim seria carga cultuada.
      #
      # ⚠️ Sem `faiResilience`: salto de LAN (<1ms), mesma justificativa do `router`.
      #
      # ⚠️ O aviso "connection is not using a post-quantum key exchange" aparece a CADA
      # conexão e NÃO é erro de config nossa: o mlkem768x25519 só existe do OpenSSH 9.9
      # em diante, e o Windows 11 (build 26200) ainda embarca o 9.5. Some sozinho quando
      # a MS atualizar o Win32-OpenSSH. Dá pra calar com `WarnWeakCrypto = "no"` (existe
      # no nosso 10.4), e é justamente por isso que NÃO está aqui: silenciar por host
      # esconde a defasagem real do servidor, e o dia em que ela for corrigida passaria
      # despercebido. O aviso é barulho honesto.
      #
      # ⚠️ authorized_keys VIVE NO WINDOWS, fora do alcance do Nix — isto declara só o
      # LADO CLIENTE, e hoje o login ainda cai em SENHA. E `ssh-copy-id` NÃO funciona
      # aqui: ele assume shell POSIX do outro lado, e do outro lado tem cmd.exe. O passo
      # manual é rodado NA máquina do irmão, e QUAL arquivo depende de o usuário ser
      # administrador — se for, o sshd do Windows IGNORA o ~/.ssh/authorized_keys dele:
      #   # usuário comum, no PowerShell:
      #   mkdir -Force $env:USERPROFILE\.ssh
      #   Add-Content $env:USERPROFILE\.ssh\authorized_keys '<conteúdo do id_ed25519.pub>'
      #   # usuário ADMIN, no PowerShell como administrador:
      #   Add-Content C:\ProgramData\ssh\administrators_authorized_keys '<a mesma linha>'
      #   icacls C:\ProgramData\ssh\administrators_authorized_keys /inheritance:r `
      #     /grant "Administrators:F" /grant "SYSTEM:F"
      # O `icacls` não é enfeite: o sshd RECUSA o arquivo (e volta pra senha, em silêncio
      # do lado do cliente) se ele for gravável por mais alguém.
      #
      # ⚠️ IP literal e por DHCP: se o roteador entregar outro endereço, o alias quebra —
      # o conserto é reserva de DHCP no OpenWrt, não mais uma opção `my.*` aqui.
      cesar = {
        HostName = "192.168.1.40";
        User = "v1cferr";
        Port = 22;
        IdentityFile = "~/.ssh/id_ed25519";
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
