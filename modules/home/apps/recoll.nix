# Recoll: an index of documents and code, so a search finds a file by CONTENT (PDF, Office, text).
# Why Recoll and not Baloo or yazi, and why each exclusion: docs/notes/apps/recoll.md
{ config, pkgs, ... }:

let
  inherit (pkgs) coreutils;
  cachedir = "${config.xdg.cacheHome}/recoll";
in
{
  # Xapian creates only the LEAF xapiandb, so a fresh cachedir failed with "mkdir failed".
  # 0700: the index holds document text in clear, readable by this user only.
  systemd.user.services.recollindex.Service.ExecStartPre =
    "${coreutils}/bin/install -d -m 0700 ${cachedir}";

  services.recoll = {
    enable = true; # recoll (Qt GUI), recollq (CLI) and the recollindex timer
    configDir = "${config.xdg.configHome}/recoll"; # XDG instead of ~/.recoll
    startAt = "hourly"; # an incremental pass: only changed files are reread
    settings = {
      inherit cachedir; # the index is data, not config
      # Only where documents and code live: the home is ~194 GB of mostly caches and games.
      topdirs = [
        "~/Documents"
        "~/Dropbox"
        "~/Downloads"
        "~/Projects"
        "~/Desktop"
      ];
      # Build output and dependencies, plus SECRETS: the index keeps the extracted text in clear.
      "skippedNames+" = [
        "node_modules"
        "result"
        "target"
        ".next"
        "dist"
        ".venv" # a Python env: 10k+ files per project, none of them mine
        ".pnpm-store" # a pnpm store inside the repo: 59k files in grad-radar alone
        "*.jar" # a zip: Recoll expands every member, and a modpack has thousands
        "*.age"
        "*.iso"
        ".env"
        ".env.*"
        "*api_keys*"
        "*key*.txt"
        "Backup-codes*"
      ];
      # Folders under a topdir that are big archives or sensitive, matched by full path.
      skippedPaths = [
        "~/Downloads/Jogos"
        "~/Downloads/minecraft-server"
        "~/Downloads/Seguranca"
        "~/Documents/curseforge" # Minecraft instances, 12k files of game data
        "~/Projects/Local/azerothcore-wotlk-coa/data" # game server data dumps
        "~/Projects/GitHub/v1cferr/ascension-coa-scraper/data/client" # 41k scraped game assets
      ];
    };
  };
}
