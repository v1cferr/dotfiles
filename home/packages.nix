# ═══════════════════════════════════════════════════════════════════════════
# THE USER'S PACKAGES (home-manager): the CENTRAL list. THIS is where you add a new app/CLI with
# NO config of its own (it mirrors system/packages.nix). Apps WITH a declarative config live in
# their own module (programs.* or apps/desktop/shell): kitty, git, dolphin, flameshot, media,
# vscode, quickshell, the theme, the Hyprland helpers.
# unfree is fine (allowUnfree is inherited from system).
#
# `pkgs.foo` = the stable base (26.05); `pkgs.unstable.foo` = the bleeding-edge channel.
# ═══════════════════════════════════════════════════════════════════════════
{ pkgs, inputs, ... }:

{
  home.packages = with pkgs; [
    # ── Browsers ──
    librewolf # a hardened Firefox (privacy)
    # Chrome from the DEV channel (unstable/latest), NOT stable, through the browser-previews
    # flake (nixpkgs only has stable). The binary/launcher is "Google Chrome Dev"; bump it with
    # `nix flake update browser-previews`. unfree; bleeding-edge compatibility/DevTools.
    inputs.browser-previews.packages.${stdenv.hostPlatform.system}.google-chrome-dev
    inputs.zen-browser.packages.${stdenv.hostPlatform.system}.default # Zen (a flake; see flake.nix)

    # ── Communication ──
    discord # voice/chat (unfree; it exposes the IPC socket for Claude Code's Rich Presence)

    # ── AI ──
    # Claude Desktop (the GUI: Chat/Cowork/Code), the OFFICIAL .deb repackaged, see flake.nix.
    # The FHS variant and not the pure one: the MCP servers need to find node/uv, and Cowork
    # brings up a QEMU VM looking for /usr/share/OVMF/*.fd and /usr/bin/virtiofsd at HARDCODED
    # FHS paths, so outside the FHS it answers "virtualization_tools_missing" and that is that.
    # The closure, MEASURED: 2.9 GiB (qemu_kvm is the biggest slice). The 30/07 measurement says
    # that is not where the disk fills up: the WHOLE /nix/store is 9% of it, the Bottles are
    # 319 GiB.
    # WARNING: Cowork requires VT-x TURNED ON IN THE BIOS (here it is off: "VMX disabled by
    # BIOS") plus the user in the kvm group. Without that, only Chat/Code work. The session and
    # claude_desktop_config.json are STATE (rule 6, so restic) and the app REWRITES that JSON at
    # runtime (rule 14: Nix does not own it). unfree.
    claude-desktop-fhs

    # ── Notes / media ──
    obsidian # Markdown notes (a local vault; unfree)
    # Music (unfree). The CEF zygote dies before the first ping: the browser aborts with "GPU
    # process isn't usable. Goodbye." and the process falls to SIGTRAP in ~250ms, with no window
    # and no visible error. `--disable-gpu` and `--no-sandbox` change nothing; only `--no-zygote`
    # works around it, and the flag lives in the PACKAGE (overlaySpotifyNoZygote, in flake.nix),
    # not in an `exec`, so that opening it from the menu picks up the same fix.
    #
    # CORRECTION (11/08/2026): this comment used to say that unstable's 1.2.92.147 "opens clean,
    # WITHOUT the flag" and that "the fix is the version, not a workaround in the launcher".
    # WRONG in both halves: 1.2.92.147 crashes just the SAME (measured again today, same message
    # and the same ~270ms), so the version was never the cause; what the 07/08 swap measured was
    # something else. It stays on `unstable` only because there is no reason to go back to the
    # base; it is the flag that keeps the app standing.
    #
    # The crash stayed INVISIBLE for 4 days because the autostart's `SuccessExitStatus=1` (which
    # exists for a good reason, see the header over there) makes the unit die CLEAN, so nothing
    # in `systemctl --user --failed`. The symptom that did show up was "the Spotify icon
    # disappeared from the tray", which does not look like a crash at all.
    unstable.spotify

    # ── Editor / dev ──
    # VS Code (the package plus the versioned settings.json/keybindings.json) lives in
    # home/apps/vscode.nix: an app WITH a config of its own owns its package.
    #
    # The Nix toolchain the nix-ide extension DRIVES: the package is declarative here, the
    # extension's config is not (home/apps/vscode/settings.json plus the repo's
    # .vscode/settings.json). Both are resolved by NAME on $PATH: a /nix/store path inside
    # settings.json would break on the first nix-collect-garbage.
    #
    # nixd and NOT nil: both are live Nix LSPs, but only nixd completes NixOS/home-manager
    # OPTIONS, because it compiles against the interpreter itself and EVALUATES the config
    # instead of analyzing text. In a repo that is 95% `services.*`/`programs.*`, that is the
    # entire job. nil is better at the rest (lighter, good diagnostics), so if nixd ever gets too
    # heavy, it is plan B, changing 1 line here and the serverPath.
    nixd
    # nixfmt and NOT nixpkgs-fmt/alejandra: it is the OFFICIAL formatter since RFC 166, which
    # created the Nix formatting team and moved the repo to the NixOS org. nixpkgs-fmt is
    # DEPRECATED by its own author; alejandra is good but unofficial, and diverging from nixpkgs
    # on style is free debt. Mind the name: `nixfmt` IS ALREADY the RFC style (1.4.0, the same
    # derivation as nixfmt-rfc-style); `nixfmt-classic` (0.6.0) is the old one, and asking for
    # the classic by mistake would reformat the whole repo in the old style.
    nixfmt
    # LINTING, which nixd does NOT do: it understands the language, it does not judge style nor
    # find dead code. Both go in together because they answer different questions and the flake's
    # gate (`checks` in flake.nix) runs both:
    #   statix  -> an idiomatic anti-pattern (say, `a = x.a;` that should be `inherit (x) a;`)
    #   deadnix -> a DEAD declaration (an unused lambda arg, let-binding or pattern)
    # Here it is only availability to run by hand; what GUARANTEES it is `nix flake check`.
    # statix's config is in ./statix.toml, with two lints turned off and justified there, because
    # 63 of the initial 77 findings were a single lint that contradicts the nixpkgs idiom (the
    # dotted path).
    statix
    deadnix

    # ── Torrent / passwords ──
    qbittorrent # the torrent GUI (manual use), separate from the headless service (system/services/qbittorrent.nix)
    bitwarden-desktop # the Electron GUI (Electron 39, EOL allowed in system/core/core.nix)
    bitwarden-cli # `bw`, to query/script the vault from the terminal

    # ── Games / emulators (bottles/ROMs/instances are STATE, so backup, rule 6) ──
    (bottles.override { removeWarningPopup = true; }) # Wine/Proton FHS-wrapped; the "Unsupported" popup silenced
    rpcs3 # a PS3 emulator (Uncharted 1/2/3); the firmware plus the games are state, you provide them
    # CurseForge (which REPLACED prismlauncher on 14/08/2026) is NOT here: it has a config of its
    # own, the login scheme handler, so it owns its package in home/apps/curseforge.nix.

    # ── Disk / cleanup ──
    # It complements filelight (which shows FOLDERS): czkawka finds what is DISPOSABLE, meaning
    # duplicates, big files, empty folders, temporaries, similar images/videos. It is the missing
    # piece for deciding what to remove instead of only seeing what is big. The GUI is
    # `czkawka_gui` (or `krokiet`, the new one); `czkawka_cli` for scripting. It does NOT delete
    # anything on its own, it always lists first.
    czkawka

    # ── CLIs ──
    gh # the GitHub CLI (auth/push over HTTPS plus a token)
    # azure-cli: 0.95 GiB MARGINAL (the closure is 1.19, but 0.24 is already on the system), and
    # the comparison with wrangler just below is fair, because the criterion is NOT size, it is
    # whether the tool does the job. wrangler cost 2.2 GiB and had NO DNS command; this one is the
    # ONLY path to the Entra ID App Registration (`az ad app …`), which is the reason everything
    # else exists. Measured on 14/08/2026: the Azure MCP Server does NOT cover Entra. Among its 68
    # tools there is no App Registration, no service principal and no Graph, its `role` is
    # RESOURCE RBAC, and `extension_cli_generate` only GENERATES the text of the `az` command, it
    # never executes. The `entra-app-registration` skill from microsoft/azure-skills confirms it
    # inside out: what it teaches is running `az ad app create/list/…`.
    # As a bonus it simplifies the MCP login: with `az` on the PATH, azmcp's chain picks up
    # AzureCliCredential and the device code stops being necessary.
    azure-cli
    # Do NOT add `wrangler` here: TESTED AND REMOVED on 07/08/2026, the same day it went in. It
    # costs 2.2 GiB of closure (FOUR copies of nodejs-24: slim, -npm, -corepack and the full one)
    # and has NO DNS/zone command, since the whole help is Workers/Pages/KV/R2/AI.
    # The DNS work here is done by the `cloudflare-api` MCP (.mcp.json at the root).
    # `claude-code` is NOT here: it has a config of its own (the separate claude-fai/claude-pessoal
    # accounts), so it owns its package in home/shell/claude-code.nix.
    unstable.yt-dlp # downloads video/audio (unstable because it breaks when the sites change)
    unstable.speedtest-cli # a speed test (unstable: it keeps up with speedtest.net's changes)
  ];
}
