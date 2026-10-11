# Recoll: an index of documents and code, so a search finds a file by CONTENT (PDF, Office, text).
# Why Recoll and not Baloo or yazi, and why each exclusion: docs/notes/apps/recoll.md
{ config, ... }:

{
  services.recoll = {
    enable = true; # recoll (Qt GUI), recollq (CLI) and the recollindex timer
    configDir = "${config.xdg.configHome}/recoll"; # XDG instead of ~/.recoll
    startAt = "hourly"; # an incremental pass: only changed files are reread
    settings = {
      cachedir = "${config.xdg.cacheHome}/recoll"; # the index is data, not config
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
      ];
    };
  };
}
