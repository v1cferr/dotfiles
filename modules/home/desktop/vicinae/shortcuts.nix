# Vicinae shortcuts (URL templates with a {query} argument), declared and merged into its own file.
# Why a merge and not a store link, and the encoding caveat: docs/notes/desktop/vicinae.md
{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:

let
  inherit (pkgs) jq writeText;

  # Fixed ids, so the merge finds them again; each opens in Zen (its desktop id), not the default opener.
  mk = id: name: domain: url: {
    id = "dotfiles-${id}";
    inherit name url;
    icon = "icon://favicon/${domain}";
    app = "zen-beta";
  };

  google = mk "google" "Search Google" "google.com" "https://www.google.com/search?q={query}";
  shortcuts = [
    google
    (mk "youtube" "Search YouTube" "youtube.com" "https://www.youtube.com/results?search_query={query}")
    # The channel this system builds from, so a hit is a package it can actually install.
    (mk "nixpkgs" "Search Nix packages" "search.nixos.org"
      "https://search.nixos.org/packages?channel=${osConfig.system.nixos.release}&query={query}"
    )
  ];

  declared = writeText "vicinae-shortcuts.json" (builtins.toJSON shortcuts);
in
{
  # Google alone: an unmatched query offers it at the bottom, and more entries there would be noise.
  my.vicinae.fallbacks = [ "shortcuts:${google.id}" ];

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
