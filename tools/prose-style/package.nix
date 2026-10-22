# prose-style: it fails on rule 17's mechanical bans, in the tree and in the commit message. What
# counts as prose, and why the naive version is wrong: docs/notes/repo/prose-style.md
{
  writeShellApplication,
  ripgrep,
  gnused,
  git,
}:

writeShellApplication {
  name = "prose-style";
  runtimeInputs = [
    ripgrep
    gnused
    git
  ];
  text = ''
    # Characters, not bytes: the codepoint of a hit, the 96-character excerpt, sed's classes.
    export LC_ALL=C.UTF-8

    # Every codepoint is an ESCAPE and this file stays pure ASCII on purpose: a checker that carries
    # the glyph it forbids is a checker that can flag itself the day the stripping rules change.
    dash=$'\u2014'
    # EMOJI AS DECORATION, narrow on purpose: the pictographic planes, three status markers and
    # VS16. BMP symbols quoted as LITERALS (U+2713, U+2764) stay out: docs/notes/repo/prose-style.md
    emoji='[\x{1F000}-\x{1FAFF}\x{2705}\x{274C}\x{26A0}]|\x{FE0F}'

    # A code span and a quoted span are LITERALS. In a COMMENT any quoted span is one, which also
    # keeps a hex color from being read as the start of a `#` comment.
    # shellcheck disable=SC2016 # sed, not shell: the backticks are literal
    literals='s/`[^`]*`//g; s/"[^"]*"//g'
    # In PROSE only a quoted GLYPH is a literal, so `"no value"` is a phrase and stays checked. A
    # table cell whose WHOLE content is the dash is the "no value" glyph, not prose.
    # shellcheck disable=SC2016 # sed, not shell: the backticks are literal
    markdown='s/`[^`]*`//g; s/"[^"[:space:]]{1,3}"//g; :a; s/\|[[:space:]]*'"$dash"'[[:space:]]*\|/||/; ta'

    # A comment opener per kind of file: after the marker it is prose, before it it is code.
    marker() {
      case "$1" in
        *.nix | *.sh | *.py | *.yaml | *.yml | *.toml | .envrc | */.envrc) echo '#' ;;
        *.lua) echo '--' ;;
        *.qml | *.js | *.mjs | *.ts | *.tsx | *.json | *.jsonc) echo '//' ;;
        *.css) echo '/*' ;;
      esac
    }

    found=()
    # One line of prose, literals already removed: a dash, then the first emoji, as findings.
    check() {
      local where=$1 n=$2 prose=$3 hit
      [[ "$prose" =~ ^[[:space:]]*(.*[^[:space:]])[[:space:]]*$ ]] && prose=''${BASH_REMATCH[1]}
      if [[ "$prose" == *"$dash"* ]]; then
        found+=("$where:$n: em dash in prose"$'\n'"    ''${prose:0:96}")
      fi
      hit=$(rg -o -P -m1 "$emoji" <<<"$prose" | head -n1 || true)
      if [[ -n "$hit" ]]; then
        found+=("$where:$n: emoji U+$(printf '%04X' "'$hit")"$'\n'"    ''${prose:0:96}")
      fi
    }

    report() {
      if ((''${#found[@]})); then
        printf 'prose-style: %d finding(s) in %s\n\n' "''${#found[@]}" "$1" >&2
        printf '  %s\n' "''${found[@]}" >&2
        printf '\nRule 17: no em dash, no emoji, no shared authorship. A LITERAL being quoted is the exception; see docs/rules.md.\n' >&2
        exit 1
      fi
      echo "prose-style: $1, clean"
    }

    # THE MESSAGE the commit is about to carry, minus git's own comment lines. A shared authorship
    # is refused here, where it can still be removed.
    if [[ "''${1:-}" == --commit-msg ]]; then
      if [[ -z "''${2:-}" ]]; then
        echo "prose-style: --commit-msg needs the message file" >&2
        exit 2
      fi
      trailers=()
      n=0
      while IFS= read -r line || [[ -n "$line" ]]; do
        n=$((n + 1))
        [[ "$line" == "#"* ]] && continue
        if [[ "''${line,,}" =~ ^[[:space:]]*co-authored-by[[:space:]]*: ]]; then
          trimmed=$line
          [[ "$line" =~ ^[[:space:]]*(.*[^[:space:]])[[:space:]]*$ ]] && trimmed=''${BASH_REMATCH[1]}
          trailers+=("commit message:$n: Co-Authored-By trailer"$'\n'"    ''${trimmed:0:96}")
        fi
        check "commit message" "$n" "$(sed -E "$literals" <<<"$line")"
      done <"$2"
      found=("''${trailers[@]}" "''${found[@]}")
      report "commit message"
    fi

    # THE TREE. Only a line holding a banned glyph can fail, so rg finds those first and the full
    # reading (fences, literals, the comment marker) runs on them alone.
    root="''${PROSE_STYLE_ROOT:-$(git rev-parse --show-toplevel)}"
    cd "$root"
    files=()
    prose=0
    while IFS= read -r f; do
      [[ -f "$f" ]] || continue
      files+=("$f")
      [[ "$f" == *.md || -n "$(marker "$f")" ]] && prose=$((prose + 1))
    done < <(git ls-files)

    while IFS=: read -r f n line; do
      if [[ "$f" == *.md ]]; then
        # A fenced block is code. The fence line itself toggles and is never prose.
        fences=0
        while IFS=: read -r at _; do
          ((at < n)) && fences=$((fences + 1))
          ((at == n)) && continue 2
        done < <(rg -n '^\s*(```|~~~)' -- "$f" || true)
        ((fences % 2)) && continue
        check "$f" "$n" "$(sed -E "$markdown" <<<"$line")"
      else
        m=$(marker "$f")
        [[ -n "$m" ]] || continue
        line=$(sed -E "$literals" <<<"$line")
        before=''${line%%"$m"*}
        [[ "$before" != "$line" ]] || continue
        check "$f" "$n" "''${line:''${#before}}"
      fi
    done < <(rg --sort path --no-heading --with-filename -n -P "\\x{2014}|$emoji" -- "''${files[@]}" || true)

    report "$prose files of prose"
  '';
}
