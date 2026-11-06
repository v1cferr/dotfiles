# WOW FOREVER ADD-ONS: a versioned list that instawow installs and keeps updated on a daily timer.
# Why instawow, the CurseForge key and how to add one: docs/notes/apps/wow-addons.md
{
  config,
  lib,
  pkgs,
  osConfig,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once.
  inherit (pkgs)
    unstable # the CHANNEL and not a package, so `unstable.x` stays greppable at each use site
    util-linux
    writeShellApplication
    ;

  # Layer 2: 26.05 ships 7.0.0, which predates the Forever flavour.
  inherit (unstable) instawow;

  # The flavour is forced: 7.2.4 knows `forever_classic` but not the `_forever_` folder name.
  profile = {
    profile = "forever";
    addon_dir = "${config.my.games.root}/World of Warcraft/_forever_/Interface/AddOns";
    flavour_override = "forever_classic";
  };

  # GitHub releases need no key, so they install even before the CurseForge one exists.
  githubAddons = [
    "github:Questie/Questie" # quest helper (bundles QuestieDB)
  ];

  # Inert until the key is in the vault (instawow answers "access token missing" without it).
  curseAddons = [
    "curse:layer" # Layer-Swap: see and change your layer
    "curse:leatrix-plus-classic" # Leatrix Plus: its Forever file lives in the Classic project
    "curse:baganator" # combined bags plus every character's inventory
    "curse:auctionator" # auction house
    "curse:bug-grabber" # BugSack's backend
    "curse:bugsack" # Lua error catcher
  ];

  cfKey = osConfig.sops.secrets.curseforge_api_key.path or null;

  wow-addons = writeShellApplication {
    name = "wow-addons";
    runtimeInputs = [
      instawow
      util-linux
    ];
    text = ''
      addons=(${lib.escapeShellArgs githubAddons})
      ${lib.optionalString (cfKey != null) ''
        if [ -r ${cfKey} ]; then
          INSTAWOW_ACCESS_TOKENS_CFCORE=$(<${cfKey})
          export INSTAWOW_ACCESS_TOKENS_CFCORE
          addons+=(${lib.escapeShellArgs curseAddons})
        fi
      ''}
      # instawow's progress bar dies without a TTY (prompt_toolkit), so a timer run gets a fake one.
      run() { if [ -t 0 ]; then instawow "$@"; else script -qec "instawow $*" /dev/null; fi; }
      # --replace adopts a copy that was unpacked by hand; an installed add-on is just skipped.
      run -p forever install --replace "''${addons[@]}"
      run -p forever update
    '';
  };
in
{
  home.packages = [
    instawow # manual use: `instawow -p forever search <name>`
    wow-addons
  ];

  xdg.configFile = {
    "instawow/config.json".text = builtins.toJSON { auto_update_check = false; }; # nix updates it
    "instawow/profiles/forever/config.json".text = builtins.toJSON profile;
  };

  systemd.user.services.wow-addons = {
    Unit.Description = "Install and update the WoW Forever add-ons";
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe wow-addons;
      Nice = 19;
    };
  };
  systemd.user.timers.wow-addons = {
    Unit.Description = "Daily WoW Forever add-on update";
    Timer = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
