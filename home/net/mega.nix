# ═══════════════════════════════════════════════════════════════════════════
# MEGA por linha de comando — megatools (`megadl`) + o wrapper `mega-dl`, que é o megadl
# com laço PACIENTE: retoma sozinho até o arquivo terminar, inclusive atravessando a cota.
#
# POR QUE megatools, depois de olhar as três alternativas:
#   • rclone — o backend `mega` fala com CONTA, não com link público (rclone#7088 segue
#     aberto). Link `/file/<id>#<chave>` não é caminho de remote, é URL com a chave no
#     fragmento; o rclone não tem onde encaixar isso.
#   • MEGAcmd (oficial) — closure enorme pra um download avulso e o `proxy` dele é
#     HTTP(S): pedido de SOCKS5 é o issue #204, aberto desde 2019.
#   • megabasterd — GUI Java; o recurso central dele é fatiar o arquivo por uma LISTA de
#     proxies pra furar a cota por IP. Não é o que este módulo faz (ver COTA, abaixo).
#   megatools é 139 KiB de closure, mantido (1.11.5, jul/2025 — protocolo do MEGA muda e
#   o upstream acompanha) e traz `--proxy socks5h://` NATIVO: o próprio man usa
#   `socks5h://localhost:9050` (Tor) como exemplo. Proxy nativo > LD_PRELOAD do torsocks.
#
# COTA — é o limite de verdade, e nenhum transporte muda isso: download anônimo tem ~5 GB
# por IP em janela DESLIZANTE de ~6 h, contada por IP (não por conta; logout não zera).
# Um arquivo de 17 GB portanto não sai de uma vez num IP só — sai em ~4 janelas.
# É por isso que o laço aqui ESPERA a janela virar em vez de trocar de IP: fatiar o
# arquivo entre IPs diferentes é justamente o que a cota existe pra impedir. Quem tem
# pressa resolve com conta Pro (`megadl -u/--username` + senha via sops, regra 12), que
# é uma linha a mais e o caminho honesto de ir rápido.
#
# RETOMADA é o que faz o laço valer: o megadl guarda o parcial em `.megatmp.<id>` no
# destino e o resume é o DEFAULT (`--disable-resume` é que desliga). O parcial é keyed
# pelo ID do arquivo, NÃO pelo transporte — dá pra começar por Tor, parar, e continuar
# direto (ou por outro proxy) de onde ficou. Testado nesta máquina.
#
# TRANSPORTE é escolha de quem chama, e o default é DIRETO:
#   • `--tor` só faz sentido pra arquivo pequeno onde o anonimato importa: circuito único
#     de 3 saltos voluntários deu 709 KiB/s aqui — 17 GiB nisso são ~7 h de banda doada,
#     e o próprio projeto Tor desencoraja granel (a rede é dimensionada pra latência
#     baixa, não pra vazão). Além disso o MEGA bloqueia parte dos exit nodes.
#   • `--proxy URL` passa qualquer proxy ÚNICO (o socks5h:// de uma VPN sua, p.ex.).
#     socks5h e não socks5: o "h" faz o proxy resolver o DNS; com socks5 puro a consulta
#     sai em claro — e o SafeSocks do system/net/tor.nix recusaria a conexão de todo jeito.
# ═══════════════════════════════════════════════════════════════════════════
{
  config,
  pkgs,
  ...
}:

let
  torSocks = "socks5h://127.0.0.1:9050"; # mesma porta do client.socksListenAddress
  destDefault = "${config.home.homeDirectory}/Downloads/mega";

  megaDl = pkgs.writeShellApplication {
    name = "mega-dl";
    runtimeInputs = with pkgs; [
      megatools
      curl
      coreutils
    ];
    text = ''
      dest='${destDefault}'
      proxy=""
      tor=0
      maxHours=48

      while [ $# -gt 0 ]; do
        case "$1" in
          --tor) tor=1; shift ;;
          --proxy) proxy=''${2:-}; shift 2 ;;
          --dest) dest=''${2:-}; shift 2 ;;
          --max-hours) maxHours=''${2:-}; shift 2 ;;
          -h | --help)
            echo "uso: mega-dl [--tor | --proxy URL] [--dest DIR] [--max-hours N] <link>"
            echo "  default: conexão direta, destino ${destDefault}, teto de 48h"
            exit 0
            ;;
          *) break ;;
        esac
      done

      link=''${1:-}
      if [ -z "$link" ]; then
        echo "uso: mega-dl [--tor | --proxy URL] [--dest DIR] <link mega.nz/file/...#chave>" >&2
        exit 2
      fi

      if [ "$tor" = 1 ]; then
        if [ -n "$proxy" ]; then
          echo "--tor e --proxy são mutuamente exclusivos." >&2
          exit 2
        fi
        proxy='${torSocks}'
        # O megadl com --proxy não cai na conexão direta, então isto não é rede de
        # segurança: é pra saber POR ONDE se sai (o exit IP) e pra falhar com a causa
        # certa quando o daemon está fora, em vez de um erro de curl do megatools.
        echo "checando o circuito Tor…"
        if ! probe=$(curl -sS --max-time 60 --socks5-hostname 127.0.0.1:9050 \
                       https://check.torproject.org/api/ip); then
          echo "o SOCKS 127.0.0.1:9050 não respondeu — o tor está no ar?" >&2
          echo "  systemctl status tor  (e my.services.tor em system/services/toggles.nix)" >&2
          exit 1
        fi
        case "$probe" in
          *'"IsTor":true'* | *'"IsTor": true'*) echo "  ✓ saída pelo Tor: $probe" ;;
          *)
            echo "  ✗ o proxy respondeu mas NÃO é Tor: $probe" >&2
            exit 1
            ;;
        esac
      fi

      mkdir -p "$dest"
      log=$(mktemp)
      trap 'rm -f "$log"' EXIT

      # Quanto já existe de parcial — é o que mostra que a espera está rendendo.
      # `|| true` e não `|| echo 0`: sem parcial nenhum o `du -c` JÁ imprime "0 total" e
      # ainda sai com erro, então o fallback saía somado ao dele ("0" duas vezes na linha).
      progresso() {
        du -shc "$dest"/.megatmp.* 2>/dev/null | tail -n1 | cut -f1 || true
      }

      maxSecs=$((maxHours * 3600))
      tentativa=0

      while [ "$SECONDS" -lt "$maxSecs" ]; do
        tentativa=$((tentativa + 1))
        echo "── tentativa $tentativa (parcial: $(progresso), decorrido: $((SECONDS / 60))min) ──"

        : > "$log"
        if [ -n "$proxy" ]; then
          set -- --proxy "$proxy"
        else
          set --
        fi
        if megadl "$@" --path "$dest" --print-names "$link" 2>&1 | tee -a "$log"; then
          echo "OK — arquivo completo em $dest"
          exit 0
        fi

        # Captura em variável e `case`, NUNCA `| grep -q`: com o pipefail do
        # writeShellApplication o grep sai no 1º match, o tail morre de SIGPIPE e o
        # pipeline retorna erro APESAR do match (a mesma pegadinha do healthcheck do
        # Sunshine). O texto vem do megatools: "Server returned %ld (over quota)".
        fim=$(tail -n 30 "$log" || true)
        case "$fim" in
          *"over quota"* | *"509"*)
            # Janela DESLIZANTE: não vira de uma vez às 6h, vai liberando aos poucos.
            # Então bater na porta de 30 em 30 min baixa mais que esperar 6h paradas.
            echo "COTA do MEGA atingida neste IP (~5 GB/6h). Esperando 30 min e retomando." >&2
            echo "  Pra ir rápido em vez de esperar: conta Pro (megadl -u <email> -p <senha>)." >&2
            sleep 1800
            ;;
          *)
            echo "  falhou por outro motivo; retomando em 15s" >&2
            sleep 15
            ;;
        esac
      done

      echo "teto de ''${maxHours}h alcançado com o download incompleto (parcial: $(progresso))." >&2
      echo "O parcial em $dest é retomável: rode o mesmo comando de novo." >&2
      exit 1
    '';
  };
in
{
  home.packages = [
    pkgs.megatools # `megadl` cru, pra download curto sem laço
    megaDl
  ];
}
