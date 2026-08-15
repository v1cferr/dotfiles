# ═══════════════════════════════════════════════════════════════════════════
# MEGA from the command line: megatools (`megadl`) plus the `mega-dl` wrapper, which is megadl
# with a PATIENT loop, resuming on its own until the file finishes, quota crossings included.
#
# WHY megatools, after looking at the three alternatives:
#   • rclone: the `mega` backend talks to an ACCOUNT, not to a public link (rclone#7088 is
#     still open). A `/file/<id>#<key>` link is not a remote path, it is a URL with the key in
#     the fragment, and rclone has nowhere to fit that.
#   • MEGAcmd (the official one): a huge closure for a one-off download, and its `proxy` is
#     HTTP(S), since a SOCKS5 request is issue #204, open since 2019.
#   • megabasterd: a Java GUI whose central feature is slicing the file across a LIST of
#     proxies to get around the per-IP quota. That is not what this module does (see QUOTA
#     below).
#   megatools is 139 KiB of closure, maintained (1.11.5, jul/2025, since the MEGA protocol
#   changes and upstream keeps up) and it brings `--proxy socks5h://` NATIVELY: its own man
#   page uses `socks5h://localhost:9050` (Tor) as the example. A native proxy beats torsocks'
#   LD_PRELOAD.
#
# QUOTA is the real limit, and no transport changes it: an anonymous download gets ~5 GB per IP
# in a SLIDING window of ~6 h, counted per IP (not per account, so logging out does not reset
# it). A 17 GB file therefore does not come down in one go on a single IP, it comes in ~4
# windows. That is why the loop here WAITS for the window to turn instead of switching IPs:
# slicing the file across different IPs is precisely what the quota exists to prevent. Anyone
# in a hurry solves it with a Pro account (`megadl -u/--username` plus the password through
# sops, rule 12), which is one extra line and the honest way to go fast.
#
# RESUMING is what makes the loop worth it: megadl keeps the partial in `.megatmp.<id>` at the
# destination and resuming is the DEFAULT (`--disable-resume` is what turns it off). The
# partial is keyed by the FILE ID, NOT by the transport, so you can start over Tor, stop, and
# continue directly (or through another proxy) from where it stopped. Tested on this machine.
#
# THE TRANSPORT is the caller's choice, and the default is DIRECT:
#   • `--tor` only makes sense for a small file where anonymity matters: a single circuit of 3
#     volunteer hops gave 709 KiB/s here, so 17 GiB over that is ~7 h of donated bandwidth, and
#     the Tor project itself discourages bulk (the network is sized for low latency, not for
#     throughput). On top of that MEGA blocks part of the exit nodes.
#   • `--proxy URL` takes any SINGLE proxy (your VPN's socks5h://, for instance). socks5h and
#     not socks5: the "h" makes the proxy resolve the DNS, since with plain socks5 the query
#     goes out in the clear, and the SafeSocks in system/net/tor.nix would refuse the
#     connection anyway.
# ═══════════════════════════════════════════════════════════════════════════
{
  config,
  pkgs,
  ...
}:

let
  torSocks = "socks5h://127.0.0.1:9050"; # the same port as client.socksListenAddress
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
        # megadl with --proxy does not fall back to the direct connection, so this is not a
        # safety net: it is here to know WHERE it goes out (the exit IP) and to fail with the
        # right cause when the daemon is down, instead of with a curl error from megatools.
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

      # How much partial already exists, which is what shows the waiting is paying off.
      # `|| true` and not `|| echo 0`: with no partial at all `du -c` ALREADY prints "0 total"
      # and still exits with an error, so the fallback came out added to it ("0" twice on the
      # line).
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

        # Captured into a variable plus a `case`, NEVER `| grep -q`: with
        # writeShellApplication's pipefail, grep exits on the 1st match, tail dies of SIGPIPE
        # and the pipeline returns an error DESPITE the match (the same trap as the Sunshine
        # healthcheck). The text comes from megatools: "Server returned %ld (over quota)".
        lastLines=$(tail -n 30 "$log" || true)
        case "$lastLines" in
          *"over quota"* | *"509"*)
            # A SLIDING window: it does not turn over all at once at 6h, it frees up bit by
            # bit. So knocking on the door every 30 min downloads more than waiting 6h idle.
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
    pkgs.megatools # raw `megadl`, for a short download with no loop
    megaDl
  ];
}
