# data-syntax: it fails on a .json/.jsonc/.toml that does not PARSE. Most of them are read by a
# TOOL at runtime and by nothing at build time, so a broken one is silent: docs/notes/repo/flake.md
{
  writeShellApplication,
  jq,
  biome,
  taplo,
}:

writeShellApplication {
  name = "data-syntax";
  runtimeInputs = [
    jq
    biome
    taplo
  ];
  text = ''
    # VS Code DOCUMENTS comments in its own settings and keybindings, and so does oxlint in its
    # own config, so these four are JSONC in spite of the .json name. Every other .json here is
    # read by a STRICT parser (Nix's fromJSON, an MCP client, Claude Code), and there a comment
    # is a broken file and not a note.
    jsonc=" .vscode/settings.json modules/home/apps/vscode/settings.json modules/home/apps/vscode/keybindings.json tools/docs-site/.oxlintrc.json "

    strict=()
    lax=()
    toml=()
    for path in "$@"; do
      case "$path" in
        *.toml) toml+=("$path") ;;
        *.jsonc) lax+=("$path") ;;
        *) if [[ "$jsonc" == *" $path "* ]]; then lax+=("$path"); else strict+=("$path"); fi ;;
      esac
    done

    broken=0

    # Exactly ONE value per file: `jq empty` alone accepts `{}{}`, which no reader here does.
    for path in "''${strict[@]}"; do
      if ! jq -n -e '[inputs] | length == 1' <"$path" >/dev/null; then
        echo "data-syntax: $path" >&2
        broken=1
      fi
    done

    # biome only as a JSONC PARSER: one rule, so a parse error is the only other way to fail.
    if ((''${#lax[@]})); then
      if ! out=$(biome lint --vcs-enabled=false \
        --json-parse-allow-comments=true --json-parse-allow-trailing-commas=true \
        --only=suspicious/noDuplicateObjectKeys "''${lax[@]}" 2>&1); then
        printf '%s\n' "$out" >&2
        broken=1
      fi
    fi

    # --no-schema, or taplo fetches a schema catalog: syntax only, and no network.
    if ((''${#toml[@]})) && ! RUST_LOG=error taplo lint --no-schema "''${toml[@]}"; then
      broken=1
    fi

    if ((broken)); then
      echo "data-syntax: the file(s) above do not parse, so whatever reads them falls back to its defaults without saying so" >&2
      exit 1
    fi

    echo "data-syntax: $# file(s) parse"
  '';
}
