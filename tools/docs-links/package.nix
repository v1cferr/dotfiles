# docs-links: it fails when a docs/ pointer does not resolve. Rule 16 says a stale note is a bug,
# and until this existed nothing enforced it. What it checks: docs/notes/repo/link-checker.md
{
  writeShellApplication,
  ripgrep,
  git,
  coreutils,
}:

writeShellApplication {
  name = "docs-links";
  runtimeInputs = [
    ripgrep
    git
    coreutils
  ];
  text = ''
    # The repo root, so the check runs the same from any cwd and inside a nix build.
    root="''${DOCS_LINKS_ROOT:-$(git rev-parse --show-toplevel)}"
    cd "$root"

    declare -A known=()
    code=()
    markdown=()
    prose=()
    modules=()
    while IFS= read -r f; do
      [[ -f "$f" ]] || continue
      known[$f]=1
      case "$f" in
        *.nix | *.lua | *.qml | *.sh | *.toml | *.yaml | *.yml | *.ts | *.tsx | *.mjs) code+=("$f") ;;
        *.md)
          markdown+=("$f")
          # `docs/history/` is a diary: it names files deleted on purpose, and editing it to
          # keep paths alive would stop it being evidence.
          [[ "$f" == docs/history/* ]] || prose+=("$f")
          ;;
      esac
      case "$f" in
        */default.nix) ;;
        modules/nixos/*.nix | modules/home/*.nix) modules+=("$f") ;;
      esac
    done < <(git ls-files)

    broken=()
    checked=0
    # A bare `docs/...` path written inside code, the form the 2-line headers use.
    pointer='\bdocs/[A-Za-z0-9_./-]+\.md\b'
    # The same pattern for bash's own matcher, which has no \b: one rg per module costs a second.
    inline='(^|[^[:alnum:]_])docs/[A-Za-z0-9_./-]+\.md([^[:alnum:]_]|$)'

    # 1. Bare docs/ pointers: CODE ONLY. A bare path inside markdown is PROSE, not a pointer:
    # rules.md cites the OLD pt-BR name of a file it renamed, which is history and correct.
    while IFS=: read -r f _ target; do
      checked=$((checked + 1))
      [[ -f "$target" ]] || broken+=("$f: pointer -> $target")
    done < <(rg --sort path --no-heading --with-filename -n -o "$pointer" -- "''${code[@]}")

    # 2. A repo path quoted in prose that describes the PRESENT (`Repo:path` is someone else's). The
    # retired roots (system, home, scripts, router) stay listed, so a path left behind FAILS.
    roots='modules|hosts|pkgs|tools|secrets|ci|system|home|scripts|router'
    while IFS=: read -r f _ target; do
      checked=$((checked + 1))
      [[ -f "$target" ]] || broken+=("$f: prose path -> $target")
    done < <(rg --sort path --no-heading --with-filename -n -o \
      -r '$1' "\`((?:$roots)/[A-Za-z0-9_./-]+\\.(?:nix|sh|py|lua|qml|json|txt|conf|yaml))\`" \
      -- "''${prose[@]}")

    # 3. Relative markdown links, resolved against the file's own directory. Only relative
    # targets matter: http(s) and #anchors are out of scope.
    links=()
    joined=()
    while IFS=: read -r f _ target; do
      case "$target" in http://* | https://* | mailto:*) continue ;; esac
      links+=("$f:$target")
      [[ "$f" == */* ]] && dir=''${f%/*} || dir=.
      joined+=("$dir/$target")
    done < <(rg --sort path --no-heading --with-filename -n -o \
      -r '$1' '\]\(([^)\s#]+\.(?:md|nix|lua|qml|sh|toml|yaml|yml))(?:#[^)]*)?\)' \
      -- "''${markdown[@]}")
    if ((''${#joined[@]})); then
      # ONE realpath for every link: -s keeps symlinks as written, -m allows a missing target.
      mapfile -t resolved < <(realpath -sm --relative-to=. -- "''${joined[@]}")
      for i in "''${!links[@]}"; do
        f=''${links[$i]%%:*}
        target=''${links[$i]#*:}
        out=''${resolved[$i]}
        checked=$((checked + 1))
        if [[ ! -f "$out" ]]; then
          broken+=("$f: link -> $target")
        # A link LEAVING docs/ is published as a GitHub blob URL by the site's hook, and an
        # untracked file is a 404 there while resolving fine here.
        elif [[ "$out" != docs/* && -z "''${known[$out]:-}" ]]; then
          broken+=("$f: untracked -> $target")
        fi
      done
    fi

    # 4. Rule 2's header: a module opens with at most 2 comment lines, holding its docs/ pointer
    # or a plain "No note". An aggregator default.nix is exempt.
    for f in "''${modules[@]}"; do
      header=""
      lines=0
      while IFS= read -r line; do
        [[ "$line" == "#"* ]] || break
        header+="$line"$'\n'
        lines=$((lines + 1))
      done <"$f"
      checked=$((checked + 1))
      if ((lines > 2)); then
        broken+=("$f: header -> $lines lines, the cap is 2")
      elif [[ ! "$header" =~ $inline && "$header" != *"No note"* ]]; then
        broken+=("$f: header -> no docs/ pointer and no 'No note'")
      fi
    done

    if ((''${#broken[@]})); then
      printf 'docs-links: %d broken of %d checked\n\n' "''${#broken[@]}" "$checked" >&2
      printf '  %s\n' "''${broken[@]}" >&2
      exit 1
    fi

    echo "docs-links: $checked references, all resolve"
  '';
}
