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
  # CLI `vpn`: connect/disconnect ufscar|fai|all → systemctl start/stop + notificação.
  vpnCli = pkgs.writeShellApplication {
    name = "vpn";
    runtimeInputs = with pkgs; [ systemd libnotify ];
    text = ''
      note() { notify-send -a VPN "VPN" "$1" 2>/dev/null || true; }
      case "''${1:-}" in
        connect)
          case "''${2:-}" in
            ufscar) systemctl start vpn-ufscar.service && note "UFSCar conectando…" ;;
            fai)    systemctl start vpn-fai.service    && note "FAI conectando…" ;;
            *) echo "uso: vpn connect ufscar|fai" >&2; exit 1 ;;
          esac ;;
        disconnect)
          case "''${2:-all}" in
            ufscar) systemctl stop vpn-ufscar.service; note "UFSCar desconectada" ;;
            fai)    systemctl stop vpn-fai.service;    note "FAI desconectada" ;;
            all)    systemctl stop vpn-ufscar.service vpn-fai.service 2>/dev/null || true; note "VPNs desconectadas" ;;
            *) echo "uso: vpn disconnect ufscar|fai|all" >&2; exit 1 ;;
          esac ;;
        *) echo "uso: vpn connect|disconnect <ufscar|fai|all>" >&2; exit 1 ;;
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
    # sem wantedBy → SOB DEMANDA (o CLI `vpn` liga)
    serviceConfig = {
      Type = "simple";
      ExecStart = pkgs.writeShellScript "vpn-ufscar-up" ''
        ${pkgs.coreutils}/bin/cat ${config.sops.secrets.ufscar_vpn_password.path} \
          | ${pkgs.openconnect}/bin/openconnect --protocol=gp --user=857722 \
              --authgroup=acessoremoto.ufscar.br --passwd-on-stdin acessoremoto-scl.ufscar.br
      '';
      Restart = "no";
    };
  };

  # FAI — SonicWall via nxBender, lendo o config renderizado pelo sops (com a senha).
  systemd.services.vpn-fai = {
    description = "VPN FAI (SonicWall via nxBender)";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.nxbender}/bin/nxBender -c ${config.sops.templates."nxbender-fai.conf".path}";
      Restart = "no";
    };
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
