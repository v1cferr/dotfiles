# VS CODE: the package plus the 3 config JSONs linked MUTABLE from the repo, because the app
# rewrites them (Settings Sync stays on). Why a mirror and not a source: docs/notes/apps/vscode.md
{
  config,
  osConfig,
  pkgs,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once. deadnix fails the build on an
  # entry that stops being used, so the list cannot rot into a lie (rule 16).
  inherit (pkgs)
    coreutils
    unstable # the CHANNEL and not a package, so `unstable.x` stays greppable at each use site
    writeShellApplication
    ;

  # The CLONED repo, from its SSOT programs.nh.flake (rule 11): the flake itself is in the store.
  repo = "${osConfig.programs.nh.flake}/modules/home/apps/vscode";

  code = unstable.vscode.override {
    commandLineArgs = "--password-store=gnome-libsecret";
  };

  # vscode-extensions-dump: it rewrites extensions.txt with what IS installed, so the extensions
  # stop being invisible to git. It MIRRORS without GOVERNING; the format's why: the notes.
  extensionsDump = writeShellApplication {
    name = "vscode-extensions-dump";
    runtimeInputs = [
      code
      coreutils
    ];
    text = ''
      repo="''${1:?usage: vscode-extensions-dump <repo-path>}"
      out="$repo/modules/home/apps/vscode/extensions.txt"
      if [ ! -d "$(dirname "$out")" ]; then
        echo "vscode-extensions-dump: $(dirname "$out") does not exist, wrong repo path?" >&2
        exit 1
      fi

      # The `|| true` is mandatory: under `set -euo pipefail` a failing `code` would kill the script
      # BEFORE the guard below could explain why.
      list="$(code --list-extensions 2>/dev/null | sort -u || true)"

      # THE GUARD: an empty list is this CLI's real FAILURE, and writing it would put the lie "I
      # uninstalled everything" into the diff. It warns and exits 0, so `update` survives.
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
    # The unstable recipe with the SRC swapped for the official tarball (see flake.nix), so it is
    # always the latest stable. The password-store override: Electron misdetects the keyring.
    code
    # On the PATH because the `update` alias calls it BY NAME; it is not a service.
    extensionsDump
  ];

  xdg.configFile."Code/User/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${repo}/settings.json";
  xdg.configFile."Code/User/keybindings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${repo}/keybindings.json";
  # mcp.json: the MCP servers VS Code's chat sees. A symlink for the same reason as the others,
  # and safe to version because the key is ${input:...}, not inline. See the notes before adding.
  xdg.configFile."Code/User/mcp.json".source = config.lib.file.mkOutOfStoreSymlink "${repo}/mcp.json";
}
