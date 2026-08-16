# THE USER'S PACKAGES: the central list for an app/CLI with no config of its own (rule 4).
# Why unstable, why azure-cli stays and wrangler did not: docs/notes/packages.md
{ pkgs, inputs, ... }:

{
  home.packages = with pkgs; [
    # ── Browsers ──
    librewolf # a hardened Firefox (privacy)
    # Chrome's DEV channel; nixpkgs only packages stable.
    inputs.browser-previews.packages.${stdenv.hostPlatform.system}.google-chrome-dev
    inputs.zen-browser.packages.${stdenv.hostPlatform.system}.default # Zen (a flake; see flake.nix)

    # ── Communication ──
    discord # it exposes the IPC socket Claude Code's Rich Presence needs

    # ── AI ──
    # The FHS variant: the MCP servers need node/uv, and Cowork looks for QEMU at hardcoded paths.
    claude-desktop-fhs

    # ── Notes / media ──
    obsidian # Markdown notes (a local vault)
    unstable.spotify # the CEF zygote crashes; --no-zygote is baked into the package by the overlay

    # ── Editor / dev ──
    # VS Code owns its package in home/apps/vscode.nix (it has settings of its own).
    nixd # the LSP that completes OPTIONS, because it evaluates the config instead of parsing text
    nixfmt # the official formatter since RFC 166; this attribute IS the rfc-style one
    statix # idiomatic anti-patterns; two lints are disabled in statix.toml
    deadnix # dead declarations (unused args, let-bindings, patterns)

    # ── Torrent / passwords ──
    qbittorrent # the GUI, separate from the headless service (system/services/qbittorrent.nix)
    bitwarden-desktop # Electron 39 is EOL and allowed explicitly in system/core/core.nix
    bitwarden-cli # `bw`, used by sync-secrets

    # ── Games / emulators (prefixes and ROMs are state, so restic, rule 6) ──
    (bottles.override { removeWarningPopup = true; }) # Wine/Proton FHS-wrapped
    rpcs3 # a PS3 emulator; the firmware and games are state, you provide them
    # CurseForge owns its package in home/apps/curseforge.nix (the login scheme handler).

    # ── Disk / cleanup ──
    czkawka # finds what is DISPOSABLE (duplicates, empties), where filelight only shows size

    # ── CLIs ──
    gh # the GitHub CLI, and the credential helper for git over HTTPS
    azure-cli # the ONLY path to the Entra ID App Registration; the Azure MCP does not cover it
    unstable.yt-dlp # it breaks when the sites change
    unstable.speedtest-cli # it follows speedtest.net's changes
  ];
}
