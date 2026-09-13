# ZEN: the browser plus a LAUNCH GUARD. A screen left locked past the grace closes it, and the next
# launch asks for Zen's OWN primary password. What it does NOT protect: docs/notes/apps/zen.md
{
  config,
  lib,
  osConfig,
  pkgs,
  inputs,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once. deadnix fails the build on an
  # entry that stops being used, so the list cannot rot into a lie (rule 16).
  inherit (pkgs)
    coreutils
    findutils
    gawk
    gnugrep
    makeWrapper
    nssTools
    procps
    rofi
    symlinkJoin
    writeShellApplication
    ;

  palette = config.my.theme.palette; # the single source (home/desktop/palette.nix)

  zen = inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # State and NOT /run: a reboot cannot be the way around the prompt.
  armedFlag = "${config.xdg.stateHome}/zen-guard/armed";

  # The guard is ONE script with two verbs, so the profile lookup and the NSS check cannot drift
  # between the arming side and the prompting side (rule 11).
  guard = writeShellApplication {
    name = "zen-guard";
    runtimeInputs = [
      coreutils
      findutils
      gawk
      gnugrep
      nssTools
      procps
      rofi
    ];
    text = ''
      flag=${lib.escapeShellArg armedFlag}

      # profiles.ini marks the default with `Default=1`; the first Path= is the fallback.
      profile_dir() {
        rel=$(awk '
          /^\[/        { p = ""; d = 0 }
          /^Path=/     { p = substr($0, 6); if (first == "") first = p }
          /^Default=1/ { d = 1 }
          d && p != "" { print p; found = 1; exit }
          END          { if (!found && first != "") print first }
        ' "$HOME/.zen/profiles.ini" 2>/dev/null)
        [ -n "$rel" ] || return 1
        printf '%s\n' "$HOME/.zen/$rel"
      }

      # 0 ONLY when NSS really authenticated: a broken db or a missing certutil is a REFUSAL and
      # never a free pass. With no primary password NSS takes whatever it is handed, which is the probe.
      nss_accepts() {
        out=$(printf '%s\n' "$2" | certutil -K -d "sql:$1" -f /dev/stdin 2>&1 || true)
        case "$out" in
        *SEC_ERROR_BAD_PASSWORD*) return 1 ;;
        *"Checking token"*) return 0 ;;
        *) return 1 ;;
        esac
      }

      # Confirmed through /proc/<pid>/exe and not by the cmdline alone: `pgrep -f` also matches a
      # shell that merely MENTIONS the pattern, and this list is about to be killed.
      zen_pids() {
        for pid in $(pgrep -f -- --class=zen-beta || true); do
          case "$(readlink -f "/proc/$pid/exe" 2>/dev/null || true)" in
          */lib/zen-bin-*/zen) printf '%s\n' "$pid" ;;
          esac
        done
      }

      case "''${1:-}" in
      arm)
        profile=$(profile_dir) || {
          echo "<4>zen-guard: no Zen profile under ~/.zen, staying DISARMED"
          exit 0
        }
        # Both refusals are LOUD and leave Zen alone: a guard that cannot check is not a guard.
        if nss_accepts "$profile" "probe-$$-$RANDOM"; then
          echo "<4>zen-guard: this Zen profile has NO primary password, so the prompt would take any answer. DISARMED"
          exit 0
        fi
        if ! grep -qF 'user_pref("browser.startup.page", 3);' "$profile/prefs.js"; then
          echo "<4>zen-guard: Zen does not reopen the previous session, so closing it would drop the tabs. DISARMED"
          exit 0
        fi
        mkdir -p "$(dirname "$flag")"
        : > "$flag"
        # SIGTERM is Firefox's clean quit (it writes sessionstore); KILL is only for a hang.
        zen_pids | xargs -r kill -TERM || true
        for _ in {1..40}; do
          if [ -z "$(zen_pids)" ]; then exit 0; fi
          sleep 0.25
        done
        zen_pids | xargs -r kill -KILL || true
        ;;
      check)
        [ -e "$flag" ] || exit 0
        profile=$(profile_dir) || {
          rofi -e "Zen guard: no profile under ~/.zen."
          exit 1
        }
        prompt="󰌾 Zen"
        for _ in 1 2 3; do
          pass=$(rofi -dmenu -password -l 0 -p "$prompt" -theme zen-guard < /dev/null) || exit 1
          [ -n "$pass" ] || exit 1
          if nss_accepts "$profile" "$pass"; then
            rm -f "$flag"
            exit 0
          fi
          prompt="󰌾 Zen (wrong password)"
        done
        exit 1
        ;;
      *)
        echo "usage: zen-guard arm|check" >&2
        exit 2
        ;;
      esac
    '';
  };

  # The desktop entry's `Exec=zen-beta` is PATH-relative, so wrapping the binary covers rofi,
  # xdg-open, $BROWSER and Dropbox's relink in one place.
  guarded = symlinkJoin {
    name = "zen-beta-guarded";
    paths = [ zen ];
    nativeBuildInputs = [ makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/zen-beta --run '${lib.getExe guard} check || exit 1'
    '';
  };
in
{
  options.my.zen = {
    package = lib.mkOption {
      type = lib.types.package;
      default = guarded;
      readOnly = true;
      description = "The session's browser, already behind the guard. Consumers read THIS (rule 11).";
    };
    grace = lib.mkOption {
      type = lib.types.str;
      default = "3min";
      description = "How long the screen stays locked before the guard closes Zen (a systemd time span).";
    };
  };

  config = {
    home.packages = [ config.my.zen.package ];

    # It arms FIRST and closes after: a Zen that is down but unguarded is an open door.
    systemd.user.services.zen-guard = {
      Unit.Description = "Arms the Zen launch guard and closes the browser";
      Service = {
        Type = "oneshot";
        ExecStart = "${lib.getExe guard} arm";
      };
      # NO Install: the timer below is the only trigger.
    };

    # The coupling lives HERE and not in lockscreen.nix: the lock does not need to know about a
    # browser, and `Wants` is weak, so a broken guard can never hold the screen unlocked.
    systemd.user.timers.zen-guard = {
      Unit = {
        Description = "Closes Zen once the screen has stayed locked";
        # BindsTo and NOT PartOf: hyprlock EXITS on unlock, and PartOf only propagates an explicit
        # stop, so the countdown would survive the unlock and kill Zen in my hands (measured).
        BindsTo = [ "hyprlock.service" ];
        After = [ "hyprlock.service" ];
      };
      Timer = {
        OnActiveSec = config.my.zen.grace;
        AccuracySec = "10s";
      };
      Install.WantedBy = [ "hyprlock.service" ];
    };

    # The prompt: the launcher's look with no list, since the only widget is the password field.
    xdg.configFile."rofi/zen-guard.rasi".text = ''
      configuration { font: "${osConfig.my.fonts.ui} 12"; }
      * {
        tn-bg:     #${palette.bg};
        tn-bg-alt: #${palette.surface};
        tn-fg:     #${palette.text};
        tn-muted:  #${palette.dim};
        tn-blue:   #${palette.blue};
        background-color: transparent;
        text-color:       @tn-fg;
      }
      window {
        width:            420px;
        background-color: @tn-bg;
        border:           2px;
        border-color:     @tn-blue;
        border-radius:    12px;
        padding:          14px;
      }
      mainbox { children: [ inputbar ]; }
      inputbar {
        background-color: @tn-bg-alt;
        border-radius:    8px;
        padding:          10px 14px;
        spacing:          10px;
        children:         [ prompt, entry ];
      }
      prompt { text-color: @tn-blue; }
      entry  { placeholder: "primary password…"; placeholder-color: @tn-muted; }
    '';
  };
}
