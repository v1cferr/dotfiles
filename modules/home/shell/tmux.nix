# tmux, for Claude sessions I can join live from the phone (Termius) while the PC stays attached.
# Why tmux and not zmx/Zellij/shpool, and the Termius side: docs/notes/apps/tmux.md
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (pkgs)
    coreutils
    git
    tmux
    writeShellApplication
    ;

  # `ctw` defaults to the personal account (personal repos); plain `claude` and `ct` keep theirs.
  ctwDefault = "pessoal";
  accounts = lib.attrNames config.my.claude.configDirs;
  accountFlags = lib.concatMapStringsSep "|" (a: "--${a}") accounts;
  accountCases = lib.concatMapStringsSep " " (a: "--${a}) account=${a} ;;") accounts;

  # `ct [claude args]`: a NEW Claude in a tmux session named after the folder (`dotfiles`, `dotfiles-2`).
  claudeTmux = writeShellApplication {
    name = "ct";
    runtimeInputs = [
      coreutils
      tmux
    ];
    text = ''
      # Already inside tmux: nesting would put a status bar inside a status bar, so just run it.
      if [ -n "''${TMUX-}" ]; then
        exec claude "$@"
      fi
      # tmux refuses `.` and `:` in a session name, and folders like `v1cferr.dev` have them.
      base=$(basename "$PWD" | tr '.:' '__')
      name=$base
      i=2
      # The `=` makes the match exact; without it `dotfiles` would also match `dotfiles-2`.
      while tmux has-session -t "=$name" 2>/dev/null; do
        name="$base-$i"
        i=$((i + 1))
      done
      exec tmux new-session -s "$name" claude "$@"
    '';
  };

  # `ca`: join a running session, picked from tmux's own session list (the phone's startup command).
  claudeAttach = writeShellApplication {
    name = "ca";
    runtimeInputs = [ tmux ];
    text = ''
      if ! tmux has-session 2>/dev/null; then
        echo "no tmux session running; start one with ct or ctw" >&2
        exit 1
      fi
      if [ -n "''${TMUX-}" ]; then
        exec tmux choose-tree -s
      fi
      exec tmux attach \; choose-tree -s
    '';
  };

  # `ctw <task> [--fai|--pessoal] [claude args]`: one task, one native worktree (`claude -w`), one session.
  claudeTmuxWorktree = writeShellApplication {
    name = "ctw";
    runtimeInputs = [
      coreutils
      git
      tmux
    ];
    text =
      assert lib.elem ctwDefault accounts;
      ''
        usage() {
          echo "usage: ctw <task-id> [${accountFlags}] [claude args...]" >&2
          echo "       ctw --prune    remove merged, clean worktrees (asks first)" >&2
          exit 2
        }

        # The MAIN checkout, even when called from inside a worktree: Claude creates them at its root.
        main_checkout() {
          if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
            echo "ctw: not inside a git working tree" >&2
            exit 1
          fi
          local first
          first=$(git worktree list --porcelain)
          first=''${first%%$'\n'*}
          echo "''${first#worktree }"
        }

        # Claude only sweeps subagent and background worktrees, so interactive ones pile up. This
        # removes a worktree only when nothing can be lost: no live session, not locked, a clean
        # tree, and a branch already merged into the default one. Squash merges look unmerged and
        # are kept. No --force and no -D, and nothing at all without a "y".
        prune() {
          local root dir def live path br lk reason ans i
          root=$(main_checkout)
          dir="$root/.claude/worktrees"
          def=$(git -C "$root" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)
          def=''${def#origin/}
          live=$(tmux list-sessions -F "#{@ctw}" 2>/dev/null || true)
          local -a gone_path=() gone_branch=() kept=()
          path="" br="" lk=""
          while IFS= read -r line; do
            case $line in
              "worktree "*) path=''${line#worktree } ;;
              "branch "*) br=''${line#branch refs/heads/} ;;
              locked*) lk=1 ;;
              "")
                if [[ $path == "$dir"/* ]]; then
                  reason=""
                  if grep -Fxq -- "$path" <<<"$live"; then
                    reason="a ctw session is running in it"
                  elif [ -n "$lk" ]; then
                    reason="locked"
                  elif [ ! -d "$path" ]; then
                    reason="folder is gone (git worktree prune)"
                  elif [ -n "$(git -C "$path" status --porcelain)" ]; then
                    reason="uncommitted changes"
                  elif [ -z "$br" ]; then
                    reason="detached HEAD"
                  elif ! git -C "$root" merge-base --is-ancestor "$br" "$def" 2>/dev/null; then
                    reason="$br not merged into $def"
                  fi
                  if [ -n "$reason" ]; then
                    kept+=("''${path#"$dir"/}: $reason")
                  else
                    gone_path+=("$path")
                    gone_branch+=("$br")
                  fi
                fi
                path="" br="" lk=""
                ;;
            esac
          done < <(git -C "$root" worktree list --porcelain; echo)

          if [ ''${#kept[@]} -gt 0 ]; then
            echo "keeping (''${#kept[@]}):"
            printf '  %s\n' "''${kept[@]}"
          fi
          if [ ''${#gone_path[@]} -eq 0 ]; then
            echo "nothing to remove"
            return
          fi
          echo "merged and clean (''${#gone_path[@]}):"
          for i in "''${!gone_path[@]}"; do
            echo "  ''${gone_path[$i]#"$dir"/}  (''${gone_branch[$i]})"
          done
          read -r -p "Remove ''${#gone_path[@]}? [y/N] " ans </dev/tty
          [[ $ans == [yY] ]] || { echo "nothing removed"; return; }
          # One failure (git refusing at the last second) must not stop the others: errexit is on.
          for i in "''${!gone_path[@]}"; do
            if ! { git -C "$root" worktree remove -- "''${gone_path[$i]}" \
              && git -C "$root" branch -d -- "''${gone_branch[$i]}"; }; then
              echo "ctw: kept ''${gone_path[$i]#"$dir"/} (git refused, see above)" >&2
            fi
          done
        }

        if [ "''${1-}" = --prune ]; then
          prune
          exit 0
        fi

        task=''${1-}
        # No dots or slashes: the id is a dir, a branch (worktree-<id>) and a tmux name all at once.
        if ! [[ $task =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]]; then
          [ -n "$task" ] && echo "ctw: invalid task id '$task' (letters, digits, - and _)" >&2
          usage
        fi
        shift

        account=${ctwDefault}
        args=()
        while [ $# -gt 0 ]; do
          case $1 in
            ${accountCases}
            --) shift; args+=("$@"); break ;;
            *) args+=("$1") ;;
          esac
          shift
        done
        if ! bin=$(command -v "claude-$account"); then
          echo "ctw: claude-$account is not on the PATH" >&2
          exit 1
        fi

        root=$(main_checkout)
        wt="$root/.claude/worktrees/$task"

        join() {
          if [ -n "''${TMUX-}" ]; then
            exec tmux switch-client -t "=$1" # never nest: hop to the task's own session
          fi
          exec tmux attach -t "=$1"
        }

        # The session is keyed by the worktree path (@ctw), not its name: a second Claude never shares it.
        while IFS=$'\t' read -r path session; do
          if [ "$path" = "$wt" ]; then join "$session"; fi
        done < <(tmux list-sessions -F "#{@ctw}"$'\t'"#{session_name}" 2>/dev/null || true)

        # tmux refuses `.` and `:`; two repos with one folder name get `-2`, `-3`.
        base="$(basename "$root" | tr '.:' '__')-$task"
        name=$base
        i=2
        while tmux has-session -t "=$name" 2>/dev/null; do
          name="$base-$i"
          i=$((i + 1))
        done

        # tmux reads an argument ending in `;` as a command separator, so escape that one.
        tmux new-session -d -s "$name" -c "$root" -- "$bin" -w "$task" "''${args[@]/%;/\\;}"
        # A failed start (e.g. an untrusted folder) keeps its pane so the error stays readable.
        if ! tmux set-option -w -t "=$name:" remain-on-exit failed 2>/dev/null \
          || ! tmux set-option -t "=$name:" @ctw "$wt" 2>/dev/null; then
          echo "ctw: claude exited at once; see why with: cd $root && claude-$account -w $task" >&2
          exit 1
        fi
        join "$name"
      '';
  };
in
{
  programs.tmux = {
    enable = true;
    terminal = "tmux-256color"; # the module defaults to `screen`, which loses italics and colors
    escapeTime = 10; # tmux's own default; the module's 500 ms lags every Esc in Claude Code
    historyLimit = 50000; # a long Claude run outgrows the 2000-line default
    baseIndex = 1; # window 1 is the first key on the keyboard, not the last
    mouse = true; # a swipe in Termius scrolls and a tap picks a session (reasoned, see the note)
    focusEvents = true; # Claude Code redraws on focus, like it does outside tmux
    extraConfig = ''
      # Shift+Enter reaches Claude Code as a newline instead of a plain Enter that submits.
      set -s extended-keys on
      set -s extended-keys-format csi-u
      # kitty does truecolor and extended keys; tmux only uses what the terminal declares.
      set -as terminal-features ',xterm-kitty:RGB:extkeys'
    '';
  };

  home.packages = [
    claudeTmux
    claudeTmuxWorktree
    claudeAttach
  ];
}
