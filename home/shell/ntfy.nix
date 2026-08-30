# `notify`: pushes a notification to the phone (ntfy) from any script or timer.
# The topic IS the password (sops), and it never takes the caller down: docs/notes/repo/shell.md
{ pkgs, ... }:

let
  # Every package this module reaches for, named ONCE and up front: an entry that stops being
  # used fails the build under deadnix, so the list cannot rot into a lie (rule 16).
  inherit (pkgs)
    coreutils
    curl
    jq
    writeShellApplication
    ;

  notify = writeShellApplication {
    name = "notify";
    runtimeInputs = [
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

      # A number in the body, but the same names ntfy accepts in a header: one vocabulary.
      case "$priority" in
        min) level=1 ;;
        low) level=2 ;;
        default) level=3 ;;
        high) level=4 ;;
        urgent) level=5 ;;
        1|2|3|4|5) level="$priority" ;;
        *) echo "notify: the priority '$priority' does not exist (min/low/default/high/urgent)" >&2; exit 2 ;;
      esac

      # Exit 0: the caller must not break because the warning did not go out.
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

      # --fail surfaces the error; --max-time keeps a service from hanging on a notification.
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
