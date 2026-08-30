# MEGA from the CLI: megatools plus a `mega-dl` wrapper with a PATIENT loop that resumes on its
# own, quota crossings included. Why megatools, and why it WAITS: docs/notes/apps/mega.md
{
  config,
  pkgs,
  ...
}:

let
  # Every package this module reaches for, named ONCE and up front: an entry that stops being
  # used fails the build under deadnix, so the list cannot rot into a lie (rule 16).
  inherit (pkgs)
    coreutils
    curl
    megatools
    writeShellApplication
    ;

  torSocks = "socks5h://127.0.0.1:9050"; # the same port as client.socksListenAddress
  destDefault = "${config.home.homeDirectory}/Downloads/mega";

  megaDl = writeShellApplication {
    name = "mega-dl";
    runtimeInputs = [
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
            echo "usage: mega-dl [--tor | --proxy URL] [--dest DIR] [--max-hours N] <link>"
            echo "  default: a direct connection, ${destDefault} as the destination, a 48h cap"
            exit 0
            ;;
          *) break ;;
        esac
      done

      link=''${1:-}
      if [ -z "$link" ]; then
        echo "usage: mega-dl [--tor | --proxy URL] [--dest DIR] <mega.nz/file/...#key link>" >&2
        exit 2
      fi

      if [ "$tor" = 1 ]; then
        if [ -n "$proxy" ]; then
          echo "--tor and --proxy are mutually exclusive." >&2
          exit 2
        fi
        proxy='${torSocks}'
        # Not a safety net (megadl does not fall back to direct): it is to know WHERE it goes out and
        # to fail with the right cause when tor is down.
        echo "checking the Tor circuit..."
        if ! probe=$(curl -sS --max-time 60 --socks5-hostname 127.0.0.1:9050 \
                       https://check.torproject.org/api/ip); then
          echo "the SOCKS at 127.0.0.1:9050 did not answer, is tor up?" >&2
          echo "  systemctl status tor  (and my.services.tor in the host panel, hosts/<host>/services.nix)" >&2
          exit 1
        fi
        case "$probe" in
          *'"IsTor":true'* | *'"IsTor": true'*) echo "  ok, going out through Tor: $probe" ;;
          *)
            echo "  the proxy answered but it is NOT Tor: $probe" >&2
            exit 1
            ;;
        esac
      fi

      mkdir -p "$dest"
      log=$(mktemp)
      trap 'rm -f "$log"' EXIT

      # How much partial exists, which is what shows the waiting is paying off. `|| true` and not
      # `|| echo 0`: with no partial, `du -c` prints "0 total" AND errors, so it would print twice.
      progress() {
        du -shc "$dest"/.megatmp.* 2>/dev/null | tail -n1 | cut -f1 || true
      }

      maxSecs=$((maxHours * 3600))
      attempt=0

      while [ "$SECONDS" -lt "$maxSecs" ]; do
        attempt=$((attempt + 1))
        echo "── attempt $attempt (partial: $(progress), elapsed: $((SECONDS / 60))min) ──"

        : > "$log"
        if [ -n "$proxy" ]; then
          set -- --proxy "$proxy"
        else
          set --
        fi
        if megadl "$@" --path "$dest" --print-names "$link" 2>&1 | tee -a "$log"; then
          echo "OK, the file is complete in $dest"
          exit 0
        fi

        # A variable plus a `case`, NEVER `| grep -q`: under pipefail the producer dies of SIGPIPE and
        # the pipeline errors DESPITE the match. The text comes from megatools.
        lastLines=$(tail -n 30 "$log" || true)
        case "$lastLines" in
          *"over quota"* | *"509"*)
            # A SLIDING window frees up bit by bit, so knocking every 30 min beats waiting 6h idle.
            echo "MEGA QUOTA reached on this IP (~5 GB/6h). Waiting 30 min and resuming." >&2
            echo "  To go fast instead of waiting: a Pro account (megadl -u <email> -p <password>)." >&2
            sleep 1800
            ;;
          *)
            echo "  it failed for another reason; resuming in 15s" >&2
            sleep 15
            ;;
        esac
      done

      echo "the ''${maxHours}h cap was reached with the download incomplete (partial: $(progress))." >&2
      echo "The partial in $dest is resumable: run the same command again." >&2
      exit 1
    '';
  };
in
{
  home.packages = [
    megatools # raw `megadl`, for a short download with no loop
    megaDl
  ];
}
