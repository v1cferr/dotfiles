# rules-index: it fails when the tree cites a rule that does not exist or was retired, and reports
# which rules nothing enforces. The numbering is API (512 citations): docs/notes/repo/rules-index.md
{
  writeShellApplication,
  ripgrep,
  git,
}:

writeShellApplication {
  name = "rules-index";
  runtimeInputs = [
    ripgrep
    git
  ];
  text = ''
    root="''${RULES_INDEX_ROOT:-$(git rev-parse --show-toplevel)}"
    cd "$root"
    rules=docs/rules.md

    # A rule is a `## N. Title` heading; a retired one keeps its number and strikes it: `## N. ~~`.
    # A card names what enforces it; a rule without the line is enforced by memory alone.
    declare -A retired=() enforced=()
    card=""
    while IFS=: read -r _ text; do
      if [[ "$text" =~ ^##\ ([0-9]+)\.\ (~~)? ]]; then
        card=''${BASH_REMATCH[1]}
        retired[$card]=''${BASH_REMATCH[2]:+1}
      elif [[ -n "$card" && -z "''${enforced[$card]:-}" && "$text" =~ ^\*\*Enforced\ by\*\*:\ (.+)$ ]]; then
        enforced[$card]=''${BASH_REMATCH[1]}
      fi
    done < <(rg -n '^## [0-9]+\. |^\*\*Enforced by\*\*: ' "$rules")

    # The history is a diary, right about its day forever; a RETIRED rule may still be named where
    # the text is about the past (a decision, a rule's long form).
    files=()
    while IFS= read -r f; do
      [[ "$f" == docs/history/* || "$f" == "$rules" || ! -f "$f" ]] || files+=("$f")
    done < <(git ls-files)

    # ONE pass in line order: a past-section heading (kept with its trailing space), any `#` line,
    # each citation run; a backtick span is a literal, skipped whole: docs/notes/repo/rules-index.md
    # shellcheck disable=SC2016 # a PCRE, not shell: the backticks are literal
    pattern='^#+ (?=The (?:long form of rule|former rule) \d+)|^#|`[^`]*`(*SKIP)(*F)'
    pattern+='|\b[Rr]ules? \d{1,3}(?![\d/])(?:(?:, | and | or )\d{1,3}(?![\d/]))*'

    bad=()
    current=""
    past=0
    while IFS= read -r hit; do
      f=''${hit%%:*}
      rest=''${hit#*:}
      lineno=''${rest%%:*}
      match=''${rest#*:}
      if [[ "$f" != "$current" ]]; then
        current=$f
        [[ "$f" == docs/decisions/* ]] && past=1 || past=0
      fi
      if [[ "$match" == "#"* ]]; then
        if [[ "$match" == *" " || "$f" == docs/decisions/* ]]; then past=1; else past=0; fi
        continue
      fi
      numbers=''${match#* }
      while [[ "$numbers" =~ ^([0-9]+)(.*)$ ]]; do
        n=''${BASH_REMATCH[1]}
        numbers=''${BASH_REMATCH[2]#, }
        numbers=''${numbers# and }
        numbers=''${numbers# or }
        n=$((10#$n))
        if [[ -z "''${retired[$n]+set}" ]]; then
          bad+=("$f:$lineno: rule $n does not exist")
        elif [[ -n "''${retired[$n]}" ]] && ((!past)); then
          bad+=("$f:$lineno: rule $n is retired")
        fi
      done
    done < <(rg --sort path --no-heading --with-filename -n -o -P "$pattern" -- "''${files[@]}")

    live=()
    memory=()
    for n in $(printf '%s\n' "''${!retired[@]}" | sort -n); do
      [[ -z "''${retired[$n]}" ]] || continue
      live+=("$n")
      how=''${enforced[$n]:-}
      [[ -n "$how" && "''${how,,}" != review* ]] || memory+=("$n")
    done
    list=$(IFS=,; echo "''${memory[*]}")
    list=''${list//,/, }
    echo "rules-index: ''${#live[@]} live rules, $((''${#live[@]} - ''${#memory[@]})) enforced by a check, ''${#memory[@]} by review alone: ''${list:-none}"

    if ((''${#bad[@]})); then
      printf '%s\n' "''${bad[@]}" >&2
      printf '\nrules-index: %d citations point at no live rule\n' "''${#bad[@]}" >&2
      exit 1
    fi
  '';
}
