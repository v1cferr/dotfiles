# ═══════════════════════════════════════════════════════════════════════════
# NOTIFY: it pushes a notification to the phone (ntfy), from any script or service.
#
# Why: disk-hygiene's notify-send only shows up IF I am in front of the machine. A timer that
# runs at 07:5x, a backup that fails in the small hours, a clock-in registered on Acuttis: I want
# to know about those in my pocket. ntfy solves it with a POST, and the phone app subscribes to a
# topic.
#
# THE TOPIC IS THE PASSWORD: on the public ntfy.sh, whoever knows the topic's name can read and
# publish. That is why it lives in sops (ntfy_topic) and NEVER in the store; the script reads
# /run/secrets/ntfy_topic at runtime. Use a random topic, not "v1cferr".
#
# To turn it on (once), IN THIS ORDER, otherwise the switch breaks:
#   1. Bitwarden: an item "ntfy Topic", with the random topic in the *password* field
#      (`openssl rand -hex 10` gives a good one). sync-secrets uses `bw get password`.
#   2. secrets/bitwarden-secrets.json: 1 more line
#        "ntfy_topic": "ntfy Topic",
#   3. `sync-secrets`  ->  `sudo nixos-rebuild switch --flake .#nixos-kingston`
#   4. In the phone app: subscribe to that same topic.
#
# Why 2 comes after 1 and before 3: entering the index makes sops DECLARE the secret, and a
# declared secret whose key is not in secrets.yaml yet passes the build and breaks at ACTIVATION
# ("secret does not exist"). The index without the encrypted value = a broken switch. While the
# line does not exist, all of this stays inert.
#
# With the secret not provisioned, the command WARNS on stderr and exits 0, so it never takes the
# caller down. A backup should not fail because the warning did not go out.
#
# The same key duo.nix already expects, so provisioning it turns both on: the Duolingo
# streak-at-risk alert was inert only for lack of this.
#
# Usage:
#   notify "Backup" "restic finished, 3.2 GiB new"
#   notify -p high -T warning "Disk" "only 4% free on /"
#
# The message goes as JSON, not as a header: an HTTP header is ASCII, and a title with an accent
# ("Backup concluído") would break at the wrong moment.
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
      secret=/run/secrets/ntfy_topic
      usage="usage: notify [-p priority] [-T tags] TITLE MESSAGE"

      priority=default
      tags=""

      while getopts "p:T:" opt; do
        case "$opt" in
          p) priority="$OPTARG" ;;
          T) tags="$OPTARG" ;;
          *) echo "$usage" >&2; exit 2 ;;
        esac
      done
      shift $((OPTIND - 1))

      if [ "$#" -lt 2 ]; then
        echo "$usage" >&2
        exit 2
      fi

      title="$1"
      shift
      message="$*"

      # ntfy wants the priority as a number in the JSON body; the names are the same ones it
      # accepts in a header, so there are not two vocabularies.
      case "$priority" in
        min) level=1 ;;
        low) level=2 ;;
        default) level=3 ;;
        high) level=4 ;;
        urgent) level=5 ;;
        1|2|3|4|5) level="$priority" ;;
        *) echo "notify: the priority '$priority' does not exist (min/low/default/high/urgent)" >&2; exit 2 ;;
      esac

      # Exit 0: the caller should not break because the warning did not go out.
      if [ ! -r "$secret" ]; then
        echo "notify: $secret is unreadable, the topic is not provisioned, nothing was sent" >&2
        exit 0
      fi

      topic="$(tr -d '[:space:]' < "$secret")"
      if [ -z "$topic" ]; then
        echo "notify: $secret is empty, nothing was sent" >&2
        exit 0
      fi

      body="$(jq -n \
        --arg topic "$topic" \
        --arg title "$title" \
        --arg message "$message" \
        --argjson priority "$level" \
        --arg tags "$tags" \
        '{topic: $topic, title: $title, message: $message, priority: $priority}
         + (if $tags == "" then {} else {tags: ($tags | split(","))} end)')"

      # --fail so an ntfy error shows up in the caller's log; --max-time so a service never hangs
      # waiting on a notification.
      curl --silent --show-error --fail --max-time 10 \
        --header "Content-Type: application/json" \
        --data "$body" \
        https://ntfy.sh >/dev/null
    '';
  };
in
{
  home.packages = [ notify ];
}
