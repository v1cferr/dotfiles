# VPNs da FAI e da UFSCar — 100% declarativo, sob demanda (não sobem no boot; o CLI
# `vpn` + os binds SUPER+N / SUPER+SHIFT+N / SUPER+CTRL+N ligam/desligam). Rodam como
# serviço systemd de sistema (VPN precisa de tun/rotas = root).
#   • UFSCar → GlobalProtect (Palo Alto) via openconnect --protocol=gp (FOSS, nixpkgs).
#   • FAI    → SonicWall SSL VPN via nxBender (FOSS, pkgs/nxbender.nix; substitui o
#              netExtender proprietário do Arch). Se não conectar → empacotar netExtender.
# Senhas via sops (Bitwarden): openconnect lê por STDIN (fora do `ps`); nxBender lê de um
# config renderizado pelo sops.templates (fora da store/git). O `vpn` dispara os serviços
# sem `sudo` graças à regra polkit abaixo (senão o bind pediria senha).
{ pkgs, config, ... }:

let
  # Teto de retentativas do Restart=always: o túnel cai sozinho ("Modem hangup" sem SIGTERM)
  # e antes ficava morto até reconectar na mão (12 min em 29/07, ~1 h em 27/07).
  # 6 tentativas por 10 min: queda real volta na 1ª; senha errada não fica martelando o
  # portal (SonicWall/GlobalProtect bloqueiam a conta) — o pill da barra apaga e você vê.
  vpnRestartGuard = {
    startLimitIntervalSec = 600;
    startLimitBurst = 6;
  };

  # CLI `vpn`: connect/disconnect ufscar|fai|all + status-json/menu (pro pill da barra).
  vpnCli = pkgs.writeShellApplication {
    name = "vpn";
    runtimeInputs = with pkgs; [ systemd libnotify rofi iproute2 gnugrep ];
    text = ''
      note() { notify-send -a VPN "VPN" "$1" 2>/dev/null || true; }
      # "Conectado" = unidade ativa E túnel existindo de fato. Só `is-active` MENTE: com
      # o portal da FAI fora do ar o nxBender entra em crash-loop e o systemd reporta
      # active durante cada tentativa (~2min), com zero ppp0 — o pill ficava verde à toa.
      # UFSCar: filtra tun[0-9] porque `type tun` também casa o tailscale0.
      fai_conn()    { systemctl is-active --quiet vpn-fai.service    && [ -n "$(ip -o link show type ppp)" ]; }
      ufscar_conn() { systemctl is-active --quiet vpn-ufscar.service && ip -o link show type tun | grep -q ': tun[0-9]'; }
      # Mount rclone da workstation FAI (~/FAI-workstation) sobe/derruba JUNTO com a VPN
      # FAI (home/services/fai-workstation-mount.nix). --no-block: não trava esperando o
      # túnel; o serviço retenta sozinho até o host ficar alcançável.
      mnt='rclone-mount:.@faiws.service'
      fai_up()      { systemctl start vpn-fai.service && note "FAI conectando…"; systemctl --user start --no-block "$mnt" 2>/dev/null || true; }
      fai_down()    { systemctl stop  vpn-fai.service 2>/dev/null || true; systemctl --user stop "$mnt" 2>/dev/null || true; note "FAI desconectada"; }
      ufscar_up()   { systemctl start vpn-ufscar.service && note "UFSCar conectando…"; }
      ufscar_down() { systemctl stop  vpn-ufscar.service 2>/dev/null || true; note "UFSCar desconectada"; }
      case "''${1:-}" in
        connect)
          case "''${2:-}" in
            ufscar) ufscar_up ;;
            fai)    fai_up ;;
            *) echo "uso: vpn connect ufscar|fai" >&2; exit 1 ;;
          esac ;;
        disconnect)
          case "''${2:-all}" in
            ufscar) ufscar_down ;;
            fai)    fai_down ;;
            all)    ufscar_down; fai_down ;;
            *) echo "uso: vpn disconnect ufscar|fai|all" >&2; exit 1 ;;
          esac ;;
        # Saída estável p/ o pill do Quickshell (Bar.qml faz o polling a cada 5s).
        status-json)
          fai=false; ufscar=false
          fai_conn    && fai=true
          ufscar_conn && ufscar=true
          printf '{"vpns":[{"id":"fai","name":"FAI","connected":%s},{"id":"ufscar","name":"UFSCar","connected":%s}]}\n' "$fai" "$ufscar" ;;
        # Menu do rofi (clique no pill): rótulo alterna conectar/desconectar por estado.
        menu)
          fai=Conectar; ufscar=Conectar
          systemctl is-active --quiet vpn-fai.service    && fai=Desconectar
          systemctl is-active --quiet vpn-ufscar.service && ufscar=Desconectar
          choice=$(printf '󰦝  %s FAI\n󰦝  %s UFSCar\n󰗼  Desconectar tudo\n' "$fai" "$ufscar" \
            | rofi -dmenu -i -p VPN -theme-str 'window { width: 340px; }') || exit 0
          case "$choice" in
            *"Conectar FAI"*)       fai_up ;;
            *"Desconectar FAI"*)    fai_down ;;
            *"Conectar UFSCar"*)    ufscar_up ;;
            *"Desconectar UFSCar"*) ufscar_down ;;
            *"Desconectar tudo"*)   ufscar_down; fai_down ;;
          esac ;;
        *) echo "uso: vpn connect|disconnect <ufscar|fai|all> | status-json | menu" >&2; exit 1 ;;
      esac
    '';
  };
in
{
  environment.systemPackages = [ vpnCli ];

  # Config do nxBender (FAI) renderizado pelo sops: params estáticos + a senha do cofre.
  # Vive em /run/secrets/rendered (root-only), nunca na store nem no git. A fingerprint
  # é do cert SELF-SIGNED da FAI (público, não é segredo) — sem ela o nxBender recusa o
  # SSL. Se a FAI trocar o certificado, pegar a nova:
  #   openssl s_client -connect 200.133.233.101:4433 | openssl x509 -noout -fingerprint -sha1
  #   (formato nxBender = sha1 minúsculo com ':').
  sops.templates."nxbender-fai.conf".content = ''
    server = 200.133.233.101
    port = 4433
    username = victor.ferreira
    domain = fai2008
    fingerprint = a9:db:84:93:e3:09:96:c7:33:6f:4d:05:ba:fa:1d:aa:59:0e:77:01
    password = ${config.sops.placeholder.fai_vpn_password}
  '';

  # UFSCar — GlobalProtect via openconnect; senha do sops por STDIN (não vaza no ps).
  # --authgroup escolhe o gateway (o portal oferece 5); senão o openconnect pede
  # interativamente e o serviço morre (stdin é só a senha → EOF).
  systemd.services.vpn-ufscar = {
    description = "VPN UFSCar (GlobalProtect via openconnect)";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    restartIfChanged = false; # rebuild não derruba túnel em uso; o daemon-reload já aplica o Restart= novo
    # sem wantedBy → SOB DEMANDA (o CLI `vpn` liga)
    serviceConfig = {
      Type = "simple";
      ExecStart = pkgs.writeShellScript "vpn-ufscar-up" ''
        ${pkgs.coreutils}/bin/cat ${config.sops.secrets.ufscar_vpn_password.path} \
          | ${pkgs.openconnect}/bin/openconnect --protocol=gp --user=857722 \
              --authgroup=acessoremoto.ufscar.br --passwd-on-stdin acessoremoto-scl.ufscar.br
      '';
      Restart = "always";
      RestartSec = 10;
    };
    # `vpn disconnect` usa systemctl stop → o systemd NÃO reinicia (stop explícito não conta).
    inherit (vpnRestartGuard) startLimitIntervalSec startLimitBurst;
  };

  # FAI — SonicWall via nxBender, lendo o config renderizado pelo sops (com a senha).
  systemd.services.vpn-fai = {
    description = "VPN FAI (SonicWall via nxBender)";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    restartIfChanged = false; # idem: reconectar a VPN é decisão sua, não efeito colateral de rebuild
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.nxbender}/bin/nxBender -c ${config.sops.templates."nxbender-fai.conf".path}";
      Restart = "always";
      RestartSec = 10;
    };
    inherit (vpnRestartGuard) startLimitIntervalSec startLimitBurst;
  };

  # polkit: deixa o usuário ligar/desligar SÓ os serviços vpn-* sem senha (pro bind
  # funcionar sem prompt). Qualquer outra unidade continua exigindo autenticação.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          subject.user == "v1cferr") {
        var unit = action.lookup("unit");
        if (unit == "vpn-ufscar.service" || unit == "vpn-fai.service") {
          return polkit.Result.YES;
        }
      }
    });
  '';
}
