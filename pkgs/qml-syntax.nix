# qml-syntax: it fails on a .qml that does not PARSE, and ignores everything else qmllint says.
# The measurement that made the rest unusable here: docs/notes/desktop/quickshell.md
{
  writeShellApplication,
  qt6,
  gnugrep,
  coreutils,
}:

writeShellApplication {
  name = "qml-syntax";
  runtimeInputs = [
    gnugrep
    coreutils
  ];
  text = ''
    # A FILE and not a shell variable: piping the output (2267 lines on this tree) into grep died
    # with "Argument list too long", and the check still exited 0, which is worse than no check.
    log="$(mktemp)"
    trap 'rm -f "$log"' EXIT

    # `|| true` because qmllint exits non-zero for any warning, and here only one CATEGORY counts:
    # a parse failure is reported as `Warning: ... [syntax]`, so there is no `Error:` to grep for.
    ${qt6.qtdeclarative}/bin/qmllint "$@" >"$log" 2>&1 || true

    if grep -q '\[syntax\]' "$log"; then
      grep -B1 -A2 '\[syntax\]' "$log" >&2
      echo "qml-syntax: the .qml above does not parse, so the bar would not start" >&2
      exit 1
    fi

    echo "qml-syntax: $# file(s) parse"
  '';
}
