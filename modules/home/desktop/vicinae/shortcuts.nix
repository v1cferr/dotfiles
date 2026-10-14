# Vicinae shortcuts (URL templates with a {query} argument), declared and merged into its own file.
# Why a merge and not a store link, and the encoding caveat: docs/notes/desktop/vicinae.md
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (pkgs) jq writeText;

  # Fixed ids, so the merge finds them again; the `app` is a desktop id (Zen, not the default opener).
  shortcuts = [
    {
      id = "dotfiles-google";
      name = "Search Google";
      icon = "icon://favicon/google.com";
      url = "https://www.google.com/search?q={query}";
      app = "zen-beta";
    }
  ];

  declared = writeText "vicinae-shortcuts.json" (builtins.toJSON shortcuts);
in
{
  # Typing anything that matches nothing offers these at the bottom of the root search.
  my.vicinae.fallbacks = map (s: "shortcuts:${s.id}") shortcuts;

  # Vicinae rewrites shortcuts.json on every open (the counters), so it cannot be a read-only link.
  # Declared entries replace their namesakes and keep their counters; GUI-made ones are untouched.
  # Before reloadSystemd, so the restart the trigger below causes reads the merged file.
  home.activation.vicinaeShortcuts =
    lib.hm.dag.entryBetween [ "reloadSystemd" ] [ "writeBoundary" ]
      ''
        f="${config.xdg.dataHome}/vicinae/shortcuts/shortcuts.json"
        run mkdir -p "$(dirname "$f")"
        now=$(date +%s)
        tmp=$(mktemp)
        { cat "$f" 2>/dev/null || echo "[]"; } | ${lib.getExe jq} --slurpfile want ${declared} --argjson now "$now" '
          (map({ key: .id, value: . }) | from_entries) as $old
          | ($want[0] | map(.id)) as $ids
          | map(select(.id as $i | $ids | index($i) | not))
            + ($want[0] | map(. + {
                openCount: ($old[.id].openCount // 0),
                createdAt: ($old[.id].createdAt // $now),
                updatedAt: ($old[.id].updatedAt // $now),
                lastUsedAt: $old[.id].lastUsedAt
              }))
        ' > "$tmp"
        run mv "$tmp" "$f"
      '';

  systemd.user.services.vicinae.Unit.X-Restart-Triggers = [ "${declared}" ];
}
