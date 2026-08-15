# VS Code: the package (the rule being that an app WITH a config of its own owns its package)
# plus the THREE user config JSONs (settings/keybindings/mcp) versioned here and linked into
# ~/.config/Code/User. The rest of that directory (globalStorage, History, workspaceStorage,
# sync) is STATE and stays out on purpose: it goes to restic, not to git.
#
# WHY mkOutOfStoreSymlink AND NOT `programs.vscode.profiles.default.userSettings`: the
# home-manager module GENERATES settings.json in the store, and the store is read-only, so the
# app, which writes to that file on every UI toggle and on every Settings Sync pull, would start
# failing with "Unable to write into user settings", and every tweak would cost a rebuild. Here
# the target is the REAL file in the repo, mutable: editing applies RIGHT AWAY (VS Code watches
# the file, with no window reload) and a toggle in the UI lands as a `git diff`. The same
# contract as hyprland.lua and quickshell (home/desktop/), for the same reason. A third gain
# comes for free: the format here is JSONC, so the settings.json COMMENTS survive, whereas a
# Nix-generated userSettings would be pure JSON and would erase them all (the "why" of
# nix.enableLanguageServer, of modernUI, of externalUriOpeners and so on).
#
# WHAT MAKES THIS SAFE, and it is the detail that decides the design: VS Code writes
# settings.json ATOMICALLY (it writes a .vsctmp and renames over it), and a rename would REPLACE
# the symlink with a regular file, silently disconnecting the repo. But it checks the target
# first: `canWriteFileAtomic` stats it and, if it is a symbolic link, returns false and falls
# back to the direct write, THROUGH the link. VERIFIED on this machine's 1.132.0
# (resources/app/out/vs/code/electron-utility/sharedProcess/sharedProcessMain.js, the shared
# process being exactly where Settings Sync runs). If VS Code ever loses that guard, the symptom
# is the symlink turning into a regular file and the repo no longer receiving the changes.
#
# SETTINGS SYNC STAYS ON, on purpose: the same account serves the FAI Windows machine (the
# settings.json has `terminal.integrated.profiles.windows` and the UNC host FAIADM6246), and
# turning the "Settings" feature off would freeze that machine forever. The consequence to
# accept: this file is a versioned MIRROR, not an immutable source, so a change made on another
# machine arrives here as a diff, and an extension that writes to the config (the fileNesting
# `"//": "Last update at …"` is the worst case) shows up in `git status`. And that is the
# FUNCTION, not the price: the repo has to mirror what the system IS, and since the linked file
# is the LIVE one, `git status` became a drift detector for the editor's config. Anyone who wants
# Nix ENFORCING swaps the `xdg.configFile` below for
# `programs.vscode.profiles.default.userSettings` and turns "Settings"/"Keybindings" off in Sync.
# That is the opposite decision, not a fix.
#
# EXTENSIONS keep being INSTALLED by Sync (the account), not declared here: declaring them would
# require the nix-vscode-extensions input (the nixpkgs set lags) plus
# `mutableExtensionsDir = false`, which breaks the UI's install button and auto-update.
# But the repo does RECORD which ones are installed, in ./vscode/extensions.txt: mirroring
# without governing (see `extensionsDump` in the let). Without that, extensions were the only
# corner of VS Code invisible to git.
#
# NB: the nixd config that carries a PATH (nixd.options/nixpkgs) lives in this repo's root
# .vscode/settings.json; it only holds with this flake as the workspace.
{ config, pkgs, ... }:

let
  # The path of the CLONED repo: there is no deriving it from inside the evaluation (the flake is
  # copied into the store; what we need is the working directory). The same literal as
  # home/desktop/hypr.nix. If the repo is not here, the symlink dangles and VS Code cannot save
  # settings, identical to what already happens with hyprland.lua.
  repo = "${config.home.homeDirectory}/Projects/GitHub/v1cferr/dotfiles/home/apps/vscode";

  code = pkgs.unstable.vscode.override {
    commandLineArgs = "--password-store=gnome-libsecret";
  };

  # vscode-extensions-dump <repo>: it rewrites extensions.txt with what IS installed.
  #
  # WHY it exists: the extensions keep being installed/updated by Settings Sync, and without this
  # file the repo would have NO RECORD of them at all. It was the last place where VS Code's
  # reality was invisible to git. Here the repo MIRRORS without GOVERNING: the same contract as
  # settings.json, one level up. Declaring them (nix-vscode-extensions plus
  # mutableExtensionsDir = false) would govern, but it breaks the UI's install button.
  #
  # The file is only IDs, one per line, sorted: `sort` because the CLI's order is arbitrary and
  # without it the diff would be shuffling instead of information. IDs and NOT `--show-versions`
  # on purpose, since the version is the marketplace's decision (auto-update), so it would churn
  # every day without carrying any decision of mine. A plain format, with no header, so it keeps
  # serving as input: `xargs -n1 code --install-extension < extensions.txt` on a new machine.
  extensionsDump = pkgs.writeShellApplication {
    name = "vscode-extensions-dump";
    runtimeInputs = [
      code
      pkgs.coreutils
    ];
    text = ''
      repo="''${1:?usage: vscode-extensions-dump <repo-path>}"
      out="$repo/home/apps/vscode/extensions.txt"
      if [ ! -d "$(dirname "$out")" ]; then
        echo "vscode-extensions-dump: $(dirname "$out") does not exist, wrong repo path?" >&2
        exit 1
      fi

      # The `|| true` is mandatory: writeShellApplication runs with `set -euo pipefail`, so a
      # `code` that fails would kill the script BEFORE the guard below could explain why.
      list="$(code --list-extensions 2>/dev/null | sort -u || true)"

      # THE GUARD: an empty list is this CLI's REAL failure (it cannot find the extensions
      # directory), and writing it would put the lie "I uninstalled everything" into the diff,
      # exactly the opposite of mirroring. It warns and exits 0: the `update` that calls this
      # should not die because the mirror failed, but it should not lie in silence either.
      if [ -z "$list" ]; then
        echo "vscode-extensions-dump: 'code --list-extensions' returned nothing, $out was NOT rewritten" >&2
        exit 0
      fi

      printf '%s\n' "$list" > "$out"
      echo "vscode-extensions-dump: $(printf '%s\n' "$list" | wc -l) extensions -> $out"
    '';
  };
in
{
  home.packages = [
    # The unstable recipe with the SRC swapped for the official tarball (the vscode-tarball input
    # plus overlayVscodeTarball in flake.nix), ahead of whatever nixpkgs bumped to. The input's
    # URL is versioned, and what raises the number is vscode-bump below, called by
    # `update`/`upgrade`: in practice, ALWAYS the latest stable. The
    # --password-store=gnome-libsecret override: under Hyprland, Electron does not autodetect the
    # secret backend and shows "couldn't identify OS keyring".
    code
    # It bumps the vscode-tarball input to the latest stable (./pkgs). On the PATH because it is
    # the `update` alias (home/shell/zsh.nix) that calls it by name, and not a service.
    pkgs.vscode-bump
    # The mirror of the installed extensions (see the let). On the PATH for the same reason as
    # vscode-bump: what calls it by name is the `update` alias.
    extensionsDump
  ];

  xdg.configFile."Code/User/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${repo}/settings.json";
  xdg.configFile."Code/User/keybindings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${repo}/keybindings.json";
  # mcp.json: which MCP servers VS Code's chat sees (context7, playwright, markitdown).
  # It goes in here for the SAME reason as the two above: it is config the app REWRITES (adding a
  # server through the gallery writes to this file), so a symlink and not `programs.vscode.userMcp`,
  # which exists but would generate into the store.
  #
  # NO SECRET here, and that is what makes versioning it safe: context7's API key is not in the
  # file, it is ${input:context7_api_key}, VS Code's NATIVE indirection, which asks for the value
  # at runtime and keeps it in globalStorage (state, so restic). CHECK THIS AGAIN when adding a
  # new server: the day one asks for an INLINE token, this file stops being versionable in the
  # clear and the path becomes sops, not a commit.
  xdg.configFile."Code/User/mcp.json".source = config.lib.file.mkOutOfStoreSymlink "${repo}/mcp.json";
}
