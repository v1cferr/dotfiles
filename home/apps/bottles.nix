# BOTTLES: the package plus the programs each bottle LISTS, inserted by an idempotent activation
# because the app owns bottle.yml and rewrites it (rule 14). Detail: docs/notes/apps/bottles.md
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Rule 19: what this module reaches for, named once.
  inherit (pkgs) bottles;

  # The popup on every launch is noise; this override used to sit in home/packages.nix.
  bottlesApp = bottles.override { removeWarningPopup = true; };

  bottlesDir = "${config.home.homeDirectory}/.local/share/bottles/bottles";

  # The DIRECTORY, which is not the name the bottle shows ("Battle.net"). See the notes.
  battlenet = "Battlenet";
  battleNetExe = "Program Files (x86)/Battle.net/Battle.net.exe";

  # A program inside a game that games-disk.nix ALREADY links: the link's key says which bottle
  # holds it and where, so neither is repeated here (rule 11), and a typo fails at eval.
  inGame =
    target: exe:
    let
      keys = lib.attrNames (lib.filterAttrs (_: t: t == target) config.my.games.linked);
    in
    if keys == [ ] then
      throw "my.games.library: '${target}' is not in my.games.linked"
    else
      {
        dir = lib.elemAt (lib.splitString "/" (lib.head keys)) 4;
        path = "${config.home.homeDirectory}/${lib.head keys}/${exe}";
      };

  # A program that is NOT the game's own exe: a launcher, or the cmd.exe that starts one.
  inBottle = dir: exe: {
    inherit dir;
    path = "${bottlesDir}/${dir}/drive_c/${exe}";
  };
in
{
  options.my.games.library = lib.mkOption {
    default = { };
    description = "The name Bottles SHOWS mapped to what it needs to list the program.";
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          dir = lib.mkOption {
            type = lib.types.str;
            description = "The bottle's directory, which is not always the name it shows.";
          };
          path = lib.mkOption {
            type = lib.types.str;
            description = "The absolute path of the .exe, the way Bottles stores it.";
          };
          arguments = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "The command line the launcher needs, empty when the exe is enough.";
          };
        };
      }
    );
  };

  config = {
    home.packages = [ bottlesApp ];

    # WHERE EACH ARGUMENT COMES FROM: the entries that already existed were read back out of
    # bottle.yml, and the two new ones from the .lnk Battle.net itself wrote in the prefix.
    my.games.library = {
      "Battle.net" = inBottle battlenet battleNetExe // {
        arguments = "--no-proxy-server --disable-features=CriticalClientHint --enable-features=UserAgentClientHint --in-process-gpu";
      };

      # Through Battle.net and NOT its own launcher, which is the route already proven here.
      "Hearthstone" = inBottle battlenet battleNetExe // {
        arguments = ''--exec="launch WTCG" --no-proxy-server --disable-features=CriticalClientHint --enable-features=UserAgentClientHint'';
      };

      # The two shims Battle.net installs. If either fails under Wine, the fallback is
      # Hearthstone's route with the product code, and it is written down in the notes.
      "Diablo IV" = inGame "Diablo IV" "Diablo IV Launcher.exe";
      "Overwatch" = inGame "Overwatch" "Overwatch Launcher.exe" // {
        arguments = "--productcode=pro";
      };

      "Cities Skylines II" = inGame "Cities - Skylines II" "Cities2.exe";
      "Assassin's Creed Black Flag Resynced" =
        inGame "Assassin Creed Black Flag Resynced" "ACBlackFlag.exe";
      "Bodycam" = inGame "Bodycam" "Bodycam.exe";

      # cmd.exe and not the launcher: it exits right after spawning, and Bottles would call the
      # program dead. The `start ""` argument is an EMPTY TITLE, not a stray pair of quotes.
      "Ascension Launcher" = inBottle "Ascension" "windows/system32/cmd.exe" // {
        arguments = ''/c start "" "C:\Program Files\Ascension Launcher\Ascension Launcher.exe"'';
      };
    };

    # ADDED, NEVER WRITTEN: Bottles rewrites bottle.yml on every change, so managing the file here
    # would be a second owner (rule 14). Same shape as dolphinPlaces: insert only what is missing.
    home.activation.bottlesLibrary = lib.hm.dag.entryAfter [ "writeBoundary" ] (
      lib.concatStrings (
        lib.mapAttrsToList (name: p: ''
          yml=${lib.escapeShellArg "${bottlesDir}/${p.dir}/bottle.yml"}
          # No bottle, nothing to do: a prefix is STATE (rule 6), restored from backup, not declared.
          if [ -f "$yml" ] && ! grep -qF ${lib.escapeShellArg "name: ${name}"} "$yml"; then
            run ${bottlesApp}/bin/bottles-cli add -b "$(sed -n 's/^Name: //p' "$yml")" \
              -n ${lib.escapeShellArg name} -p ${lib.escapeShellArg p.path} \
              ${lib.optionalString (p.arguments != "") "-l ${lib.escapeShellArg p.arguments}"}
          fi
        '') config.my.games.library
      )
    );
  };
}
