# dead-config: it fails when something is DECLARED and never used (rule 16, which only memory
# enforced before). The checks and the review dates: docs/notes/repo/dead-config.md
{
  writeShellApplication,
  ripgrep,
  jq,
  git,
  coreutils,
}:

writeShellApplication {
  name = "dead-config";
  runtimeInputs = [
    ripgrep
    jq
    git
    coreutils
  ];
  text = ''
    export LC_ALL=C
    root="''${DEAD_CONFIG_ROOT:-$(git rev-parse --show-toplevel)}"
    cd "$root"

    # A tracked exception needs a REASON and a REVIEW date (rule 22); the canary runs --expired
    # weekly. Emptying this list is the goal, not growing it. Keyed by kind and BASENAME.
    declare -A why=() by=()
    # The frozen home repo on the Seagate is garbage without it: docs/notes/boot-and-storage/restic.md
    why[secret:restic_password]="reads the frozen home repo on the Seagate" by[secret:restic_password]=2026-12-31
    # Its consumer is OUTSIDE this tree: the home-automation repo's tooling reads /run/secrets.
    why[secret:home_assistant_token]="read by the home-automation repo, not by Nix" by[secret:home_assistant_token]=2027-04-30
    # A policy no module implements: the README's License section is its only way in.
    why[note:docs/notes/repo/license.md]="the why of LICENSE, reached from the README" by[note:docs/notes/repo/license.md]=2027-09-29

    # Rule 22's clock half: an exception past its review date. It never runs in the gate.
    if [[ "''${1:-}" == --expired ]]; then
      # The `# review-by:` above each allowlist in .config/gitleaks.toml, keyed by its description.
      if [[ -f .config/gitleaks.toml ]]; then
        while IFS=$'\t' read -r date desc; do
          why[gitleaks:$desc]=$desc by[gitleaks:$desc]=$date
        done < <(rg -U -o -P -r $'$1\t$2' \
          '# review-by: (\d{4}-\d{2}-\d{2})\n(?:#.*\n)*\[\[rules\.allowlists\]\]\ndescription = "([^"]+)"' \
          .config/gitleaks.toml || true)
      fi
      today=$(date +%F)
      late=0
      while IFS= read -r key; do
        if [[ "''${by[$key]}" < "$today" ]]; then
          echo "dead-config: $key was due for review on ''${by[$key]} (''${why[$key]})" >&2
          late=1
        fi
      done < <(printf '%s\n' "''${!by[@]}" | sort)
      if ((late)); then
        printf '\nDelete it, or move the date in a commit that says why.\n' >&2
        exit 1
      fi
      echo "dead-config: ''${#by[@]} exceptions, none past its review date"
      exit 0
    fi

    files=()
    code=()
    nix=()
    while IFS= read -r f; do
      [[ -f "$f" ]] || continue
      files+=("$f")
      case "$f" in *.nix | *.lua | *.qml | *.sh | *.toml | *.yaml | *.yml) code+=("$f") ;; esac
      [[ "$f" != *.nix ]] || nix+=("$f")
    done < <(git ls-files)

    findings=()
    allowed=()
    flag() {
      local key="$1:''${2##*/}"
      if [[ -n "''${why[$key]:-}" ]]; then
        allowed+=("dead-config: allowed $1 $2: ''${why[$key]} (review by ''${by[$key]})")
      else
        findings+=("$1: $2 ($3)")
      fi
    }

    # 1. A .nix under modules/, hosts/ or flake/ that nothing imports is a file nobody evaluates.
    # The `imports` blocks and every `import ./x` become edges; jq resolves them and walks from the roots.
    while IFS= read -r f; do
      flag module "$f" "no \`imports\` reaches it"
    done < <(rg --json -U -P 'imports\s*=\s*\[(?s:.*?)\]|\bimport\s+\.\.?/[A-Za-z0-9_./-]+' -- "''${nix[@]}" |
      jq -nr --args '
        ($ARGS.positional | map({(.): true}) | add) as $nix
        | def norm: split("/") | reduce .[] as $s ([];
            if $s == "." or $s == "" then . elif $s == ".." and length > 0 and .[-1] != ".." then .[:-1]
            else . + [$s] end) | join("/");
        # `./x` and `../x` alike; the lookbehind keeps the `./` inside a `../` from matching too shallow.
        ([inputs | select(.type == "match") | .data.path.text as $f
          | ($f | split("/") | .[:-1] | join("/")) as $base
          | .data.submatches[].match.text
          | scan("(?<![\\w.])(\\.\\.?/[A-Za-z0-9_./-]+)")[0]
          | (if $base == "" then . else "\($base)/\(.)" end | norm) as $p
          | [$p + ".nix", $p + "/default.nix", $p] | map(select($nix[.])) | first // empty
          | {from: $f, to: .}] | group_by(.from) | map({(.[0].from): map(.to)}) | add // {}) as $edges
        | (["flake.nix", "modules/nixos/default.nix", "modules/home/default.nix"]
           + ($nix | keys | map(select(startswith("hosts/"))))) as $roots
        | {seen: {}, stack: $roots}
        | until(.stack | length == 0;
            .stack[-1] as $f | .stack |= .[:-1]
            | if .seen[$f] then . else .seen[$f] = true | .stack += ($edges[$f] // []) end)
        | .seen as $seen
        # pkgs/ and tools/ are reached by callPackage in flake.nix, not by an `imports` list.
        | $nix | keys[] | select(($seen[.] | not) and (startswith("pkgs/") or startswith("tools/") | not) and . != "flake.nix")
      ' "''${nix[@]}")

    # 2. A flake input nothing consumes still gets fetched, locked and evaluated. The declaration
    # block is cut out of flake.nix, so a name that appears ONLY there is never consumed.
    flake=$(<flake.nix)
    head=''${flake%%"inputs = {"*}
    tail=''${flake#*"inputs = {"}
    rest=$(mktemp)
    trap 'rm -f "$rest"' EXIT
    printf '%s\n%s' "$head" "''${tail#*$'\n  outputs ='}" >"$rest"
    others=()
    for f in "''${code[@]}"; do [[ "$f" == flake.nix ]] || others+=("$f"); done
    while IFS= read -r name; do
      rg -q -w -F -- "$name" "$rest" "''${others[@]}" || flag input "$name" "declared in flake.nix, consumed nowhere"
    done < <(jq -r '.nodes[.root].inputs | keys[]' flake.lock)

    # 3. A `my.*` option nobody reads is an SSOT with no consumer, which rule 11 exists to avoid.
    # A consumer may read the option itself or one of its children.
    while IFS= read -r opt; do
      rg -q -P "(config|osConfig)\\.my\\.''${opt//./\\.}\\b" -- "''${code[@]}" ||
        flag option "my.$opt" "declared, never read through config/osConfig"
    done < <(rg -U -o -P --no-filename -r '$1' 'options\.my\.([A-Za-z0-9_.]+)\s*=' -- "''${code[@]}" | sort -u)

    # 4. A note no module points at is unreachable: rule 2 made the pointer the only path in. The
    # other door is a rule card's Detail link, for a note that holds a rule's long form.
    notes=()
    for f in "''${files[@]}"; do
      [[ "$f" == docs/notes/*.md && "''${f##*/}" != README.md ]] && notes+=("$f")
    done
    declare -A reached=()
    while IFS= read -r hit; do reached[$hit]=1; done < <(
      rg -o -F --no-filename -f <(printf '%s\n' "''${notes[@]}") -- "''${code[@]}" || true
      rg -o --no-filename -r 'docs/$1' '\]\((notes/[^)#]+\.md)' docs/rules.md || true
    )
    for f in "''${notes[@]}"; do
      [[ -n "''${reached[$f]:-}" ]] || flag note "$f" "no pointer from any module"
    done

    # 5. A sops secret nothing consumes is a credential kept, re-encrypted and rotated for nobody.
    mapfile -t keys < <(rg -o -r '$1' '^([a-z0-9_]+):' secrets/secrets.yaml | sort -u)
    for k in "''${keys[@]}"; do
      [[ "$k" != sops ]] || continue # sops' own metadata block, not a secret
      rg -q -U -P "/run/secrets/$k\\b|sops\\.secrets\\.?\\W*$k\\b|sops\\.placeholder\\.$k\\b" -- "''${code[@]}" ||
        flag secret "$k" "in secrets.yaml, consumed nowhere"
    done

    # 6. An index entry with no value in the vault breaks the BUILD at `nixos-rebuild`, a much
    # slower loop than this: secrets.nix makes every key of the index a `sops.secrets.<name>`.
    declare -A vault=()
    for k in "''${keys[@]}"; do vault[$k]=1; done
    while IFS= read -r k; do
      [[ -n "''${vault[$k]:-}" ]] || flag secret-index "$k" "in bitwarden-secrets.json, no value in secrets.yaml"
    done < <(jq -r 'keys[]' secrets/bitwarden-secrets.json)

    # 7. A tracked build artifact is dead by definition. A .gitignore only stops what is not
    # tracked YET, which is how a .pyc once stayed committed and invisible to it.
    while IFS= read -r f; do
      flag artifact "$f" "build output or editor dropping, should not be tracked"
    done < <(printf '%s\n' "''${files[@]}" | sort |
      rg -P '(^|/)(__pycache__|\.direnv|node_modules|result(-.*)?)(/|$)|\.py[cod]$|\.(swp|swo|orig|rej|bak|tmp)$|(^|/)\.DS_Store$' || true)

    ((''${#allowed[@]} == 0)) || printf '%s\n' "''${allowed[@]}"
    if ((''${#findings[@]})); then
      printf '\ndead-config: %d declared and never used\n\n' "''${#findings[@]}" >&2
      printf '  %s\n' "''${findings[@]}" >&2
      printf '\nRemove it, or add it to ALLOWED with a reason and a review date.\n' >&2
      exit 1
    fi
    echo "dead-config: 7 checks, nothing declared and unused"
  '';
}
