# ═══════════════════════════════════════════════════════════════════════════
# NOTIFY — empurra notificação pro celular (ntfy), de qualquer script ou serviço.
#
# Porquê: o notify-send do disk-hygiene só aparece SE eu estiver na frente da
# máquina. Timer que roda 07:5x, backup que falha de madrugada, ponto batido no
# Acuttis — disso eu quero saber no bolso. O ntfy resolve com um POST, e o app
# do celular assina um tópico.
#
# O TÓPICO É A SENHA: no ntfy.sh público, quem sabe o nome do tópico lê e
# publica. Por isso ele vive no sops (ntfy_topic) e NUNCA na store — o script lê
# /run/secrets/ntfy_topic em runtime. Use um tópico aleatório, não "v1cferr".
#
# Ligar (uma vez):
#   1. Bitwarden: item "ntfy Topic", com o tópico aleatório no campo *senha*
#      (`openssl rand -hex 10` dá um bom). O sync-secrets usa `bw get password`.
#   2. `sync-secrets`  →  `sudo nixos-rebuild switch --flake .#nixos-kingston`
#   3. No app do celular: assinar esse mesmo tópico.
#
# Sem o segredo provisionado o comando AVISA no stderr e sai 0 — nunca derruba
# quem chamou. Um backup não deve falhar porque o aviso não saiu.
#
# Mesma chave que o duo.nix já espera, então provisionar liga os dois: o alerta
# de ofensiva em risco do Duolingo estava inerte só por falta disto.
#
# Uso:
#   notify "Backup" "restic terminou, 3.2 GiB novos"
#   notify -p high -T warning "Disco" "só 4% livre em /"
#
# A mensagem vai como JSON, não como header: header de HTTP é ASCII, e título
# com acento ("Backup concluído") quebraria na hora errada.
# ═══════════════════════════════════════════════════════════════════════════
{ pkgs, ... }:

let
  notify = pkgs.writeShellApplication {
    name = "notify";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      jq
    ];
    text = ''
      segredo=/run/secrets/ntfy_topic
      uso="uso: notify [-p prioridade] [-T tags] TÍTULO MENSAGEM"

      prioridade=default
      tags=""

      while getopts "p:T:" opcao; do
        case "$opcao" in
          p) prioridade="$OPTARG" ;;
          T) tags="$OPTARG" ;;
          *) echo "$uso" >&2; exit 2 ;;
        esac
      done
      shift $((OPTIND - 1))

      if [ "$#" -lt 2 ]; then
        echo "$uso" >&2
        exit 2
      fi

      titulo="$1"
      shift
      mensagem="$*"

      # O ntfy quer a prioridade como número no corpo JSON; os nomes são os
      # mesmos que ele aceita em header, pra não ter dois vocabulários.
      case "$prioridade" in
        min) nivel=1 ;;
        low) nivel=2 ;;
        default) nivel=3 ;;
        high) nivel=4 ;;
        urgent) nivel=5 ;;
        1|2|3|4|5) nivel="$prioridade" ;;
        *) echo "notify: prioridade '$prioridade' não existe (min/low/default/high/urgent)" >&2; exit 2 ;;
      esac

      # Sair 0: quem chamou não deve quebrar porque o aviso não saiu.
      if [ ! -r "$segredo" ]; then
        echo "notify: $segredo ilegível — tópico não provisionado, nada enviado" >&2
        exit 0
      fi

      topico="$(tr -d '[:space:]' < "$segredo")"
      if [ -z "$topico" ]; then
        echo "notify: $segredo está vazio, nada enviado" >&2
        exit 0
      fi

      corpo="$(jq -n \
        --arg topic "$topico" \
        --arg title "$titulo" \
        --arg message "$mensagem" \
        --argjson priority "$nivel" \
        --arg tags "$tags" \
        '{topic: $topic, title: $title, message: $message, priority: $priority}
         + (if $tags == "" then {} else {tags: ($tags | split(","))} end)')"

      # --fail pra que erro do ntfy apareça no log de quem chamou; --max-time
      # pra que um serviço nunca fique pendurado esperando notificação.
      curl --silent --show-error --fail --max-time 10 \
        --header "Content-Type: application/json" \
        --data "$corpo" \
        https://ntfy.sh >/dev/null
    '';
  };
in
{
  home.packages = [ notify ];
}
