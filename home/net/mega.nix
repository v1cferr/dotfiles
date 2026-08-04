# ═══════════════════════════════════════════════════════════════════════════
# MEGA por linha de comando — megatools (`megadl`) + o wrapper `mega-tor`, que é o
# megadl já apontado pro SOCKS do Tor (system/net/tor.nix) com retomada em laço.
#
# POR QUE megatools, depois de olhar as três alternativas:
#   • rclone — o backend `mega` fala com CONTA, não com link público (rclone#7088 segue
#     aberto). Link `/file/<id>#<chave>` não é caminho de remote, é URL com a chave no
#     fragmento; o rclone não tem onde encaixar isso.
#   • MEGAcmd (oficial) — closure enorme pra um download avulso e, pior, o `proxy` dele é
#     HTTP(S): pedido de SOCKS5 é o issue #204, aberto desde 2019. Sem SOCKS não há Tor.
#   • megabasterd — GUI Java; o recurso de proxy dele é LISTA de proxies pra furar a cota
#     de download, não anonimato. Objetivo diferente do daqui.
#   megatools é 139 KiB de closure, mantido (1.11.5, jul/2025 — protocolo do MEGA muda e
#   o upstream acompanha) e traz `--proxy socks5h://` NATIVO: o próprio man usa
#   `socks5h://localhost:9050` (Tor) como exemplo. Proxy nativo > LD_PRELOAD do torsocks.
#
# socks5h e NÃO socks5: o "h" faz o Tor resolver o hostname. Com socks5 puro a consulta de
# DNS sai da máquina em claro — e o SafeSocks do tor.nix recusaria a conexão de todo jeito.
#
# LAÇO DE TENTATIVAS: circuito Tor cai no meio de download longo, e isso é normal, não
# defeito. O resume do megadl é o DEFAULT (`--disable-resume` é que desliga), então cada
# tentativa retoma o arquivo parcial em vez de recomeçar.
#
# LIMITES QUE NÃO SÃO BUG DESTE MÓDULO:
#   • O MEGA bloqueia parte dos exit nodes do Tor — falha imediata e repetida em TODAS as
#     tentativas costuma ser exit bloqueado, não link ruim. Circuito novo = restart do tor.
#   • Conta grátis tem cota de banda por IP (~5 GB/24h); o exit node é um IP compartilhado,
#     então ele pode chegar já gasto por outra pessoa.
#   • Velocidade de circuito único. Arquivo de muitos GB por Tor é castigo — nesse caso
#     `megadl` direto (está no PATH) ou VPN.
# ═══════════════════════════════════════════════════════════════════════════
{
  config,
  pkgs,
  ...
}:

let
  # Mesma porta do client.socksListenAddress do system/net/tor.nix.
  torSocks = "socks5h://127.0.0.1:9050";
  destDefault = "${config.home.homeDirectory}/Downloads/mega";

  megaTor = pkgs.writeShellApplication {
    name = "mega-tor";
    runtimeInputs = with pkgs; [
      megatools
      curl
      coreutils
    ];
    text = ''
      link=''${1:-}
      dest=''${2:-${destDefault}}

      if [ -z "$link" ]; then
        echo "uso: mega-tor <link mega.nz/file/...#chave> [destino]" >&2
        echo "     destino default: ${destDefault}" >&2
        exit 2
      fi

      mkdir -p "$dest"

      # O megadl com --proxy não tem como cair na conexão direta, então este teste não é
      # rede de segurança: é pra saber POR ONDE se está saindo (o exit IP) e pra falhar com
      # a causa certa quando o daemon está fora, em vez de um erro de curl do megatools.
      echo "checando o circuito Tor…"
      if ! probe=$(curl -sS --max-time 60 --socks5-hostname 127.0.0.1:9050 \
                     https://check.torproject.org/api/ip); then
        echo "o SOCKS 127.0.0.1:9050 não respondeu — o tor está no ar?" >&2
        echo "  systemctl status tor" >&2
        echo "  e confira my.services.tor = true em system/services/toggles.nix" >&2
        exit 1
      fi
      case "$probe" in
        *'"IsTor":true'* | *'"IsTor": true'*) echo "  ✓ saída pelo Tor: $probe" ;;
        *)
          echo "  ✗ o proxy respondeu mas NÃO é Tor: $probe" >&2
          exit 1
          ;;
      esac

      for try in $(seq 1 10); do
        echo "── tentativa $try/10 ──"
        if megadl --proxy '${torSocks}' --path "$dest" --print-names "$link"; then
          echo "OK — arquivo em $dest"
          exit 0
        fi
        echo "  tentativa $try falhou; retomando em 5s" >&2
        sleep 5
      done

      echo "desisti depois de 10 tentativas." >&2
      echo "Se TODAS falharam na hora, provavelmente é exit node bloqueado pelo MEGA." >&2
      echo "Sorteie outro circuito e rode de novo (o parcial em $dest é retomado):" >&2
      echo "  sudo systemctl restart tor" >&2
      exit 1
    '';
  };
in
{
  home.packages = [
    pkgs.megatools # `megadl` cru, sem proxy — pra quando o Tor não vale a pena
    megaTor
  ];
}
