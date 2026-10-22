# `router-sync`: mirrors the OpenWrt UCI into the repo, secrets redacted, and never pushes. The
# fail-safe redaction and why each public name is released: docs/notes/repo/router-ssot.md
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once. deadnix fails the build on an
  # entry that stops being used, so the list cannot rot into a lie (rule 16).
  inherit (pkgs)
    coreutils
    git
    openssh
    writeShellApplication
    ;

  cfg = config.my.router;
  inherit (lib) mkOption types;
in
{
  # The router this machine manages. NO default: the host wires the router's own data file.
  options.my.router = {
    address = mkOption {
      type = types.str;
      description = "The router's LAN address: the gateway, and where router-sync and `ssh router` connect.";
    };
    sshUser = mkOption {
      type = types.str;
      description = "The account router-sync logs into (it reads with `sudo uci show`).";
    };
    mirror = mkOption {
      type = types.str;
      description = "The UCI mirror's folder, relative to the repo root: router-sync writes it there.";
    };
  };

  # The logic lives in the build (rule 7); openssh is explicit so it never uses the user's PATH.
  # pull brings the device's state over, diff exits 1 on drift; NEITHER writes to the router.
  config.environment.systemPackages = [
    (writeShellApplication {
      name = "router-sync";
      runtimeInputs = [
        coreutils
        openssh
        git # it finds the repo's root (the same idiom as modules/nixos/core/sync-secrets.sh)
      ];
      text = ''
        export LC_ALL=C
        shopt -s extglob
        host=${lib.escapeShellArg "${cfg.sshUser}@${cfg.address}"}
        marker="<REDACTED: the real value is on the router; see docs/history/>"

        action="''${1:-diff}"
        case "$action" in
        pull | diff) ;;
        *)
          echo "usage: router-sync [pull|diff]  (got: $action)" >&2
          exit 2
          ;;
        esac

        # The script lives in /nix/store, so the repo is found from the CWD, never from the script.
        top=$(git rev-parse --show-toplevel 2>/dev/null) || {
          echo "run it from inside the repo (git rev-parse failed)." >&2
          exit 2
        }
        root=${lib.escapeShellArg cfg.mirror}
        [[ "$root" == /* ]] || root="$top/$root"

        err=$(mktemp)
        trap 'rm -f "$err"' EXIT
        remote() {
          if ! ssh -n -o BatchMode=yes -o ConnectTimeout=10 "$host" "$1" 2>"$err"; then
            echo "ssh failed: $(<"$err")" >&2
            exit 2
          fi
        }

        # FAIL-SAFE redaction: a leaf naming a credential (as a SUBSTRING: `rpcd_token` once leaked
        # in the clear) is redacted unless it is one of the measured public names. Rule 12.
        suspect=(private_key preshared_key password passwd psk secret token key)
        public=" public_key key_type passwordauth rootpasswordauth "
        redact() {
          local line=$1 option value leaf s hit=0
          [[ "$line" == *=* ]] || { printf '%s\n' "$line"; return; }
          option=''${line%%=*}
          value=''${line#*=}
          leaf=''${option##*.}
          leaf=''${leaf,,}
          for s in "''${suspect[@]}"; do [[ "$leaf" == *"$s"* ]] && hit=1; done
          # A file PATH is a pointer, not a secret: uhttpd.main.key and the like.
          value=''${value##+([\'\"])}
          if [[ "$public" == *" $leaf "* ]] || ((!hit)) || [[ "$value" == /* ]]; then
            printf '%s\n' "$line"
          else
            printf "%s='%s'\n" "$option" "$marker"
          fi
        }

        # `uci show`, one line per option; each ssh into a VARIABLE, since an `exit` inside `$(...)`
        # only leaves the subshell and errexit on the assignment is what makes it the script's exit 2.
        declare -A live=()
        configs=$(remote "ls /etc/config/")
        while IFS= read -r c; do
          [[ -z "$c" || "$c" == *.bak* || "$c" == *-bak* ]] && continue
          raw=$(remote "sudo uci show $c 2>/dev/null || true")
          text=""
          while IFS= read -r line; do
            [[ -n "''${line//[[:space:]]/}" ]] && text+="$(redact "$line")"$'\n'
          done <<<"$raw"
          [[ -z "$text" ]] || live[$c]=$text
        done < <(sort <<<"$configs")
        names=$(printf '%s\n' "''${!live[@]}" | sort)
        same() { [[ -f "$2" ]] && cmp -s <(printf '%s' "$1") "$2"; }

        if [[ "$action" == pull ]]; then
          mkdir -p "$root"
          for old in "$root"/*.conf; do
            [[ -e "$old" ]] || continue
            name=''${old##*/}
            if [[ -z "''${live[''${name%.conf}]+set}" ]]; then
              rm -f "$old"
              echo "  removed  $name (it no longer exists on the router)"
            fi
          done
          for c in $names; do
            target="$root/$c.conf"
            same "''${live[$c]}" "$target" && continue
            [[ -f "$target" ]] && verb=updated || verb=new
            printf '%s' "''${live[$c]}" >"$target"
            printf '  %-10s %s.conf\n' "$verb" "$c"
          done
          printf '\n%d configs in %s\n' "''${#live[@]}" "$root"
          exit 0
        fi

        diverged=0
        for c in $names; do
          target="$root/$c.conf"
          if [[ ! -f "$target" ]]; then
            echo "  ROUTER ONLY  $c"
            diverged=1
          elif ! same "''${live[$c]}" "$target"; then
            echo "  DIVERGES     $c"
            diverged=1
          fi
        done
        for old in "$root"/*.conf; do
          [[ -e "$old" ]] || continue
          name=''${old##*/}
          name=''${name%.conf}
          if [[ -z "''${live[$name]+set}" ]]; then
            echo "  REPO ONLY    $name"
            diverged=1
          fi
        done
        if ((diverged)); then
          echo
          echo "run \`router-sync pull\` to bring the router's state over."
          exit 1
        fi
        echo "the router and the repo are in sync."
      '';
    })
  ];
}
