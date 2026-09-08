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
  inherit (pkgs)
    bottles
    coreutils
    curl
    gawk
    gnugrep
    gnused
    jq
    writeShellApplication
    ;

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

  # THE LIBRARY IS A SECOND FILE and no CLI covers it, so this is what inserts into it. It exists
  # as a package and not as activation text because the parsing needs awk (rule 7, shellcheck).
  libraryAdd = writeShellApplication {
    name = "bottles-library-add";
    runtimeInputs = [
      coreutils
      curl
      gawk
      gnugrep
      gnused
      jq
    ];
    text = ''
      dir="$1"
      program="$2"
      yml="${bottlesDir}/$dir/bottle.yml"
      lib="${config.home.homeDirectory}/.local/share/bottles/library.yml"

      # No bottle at all: a prefix is STATE (rule 6), so there is nothing to link yet.
      [ -f "$yml" ] || exit 0

      # THE ENTRY POINTS AT THE PROGRAM'S UUID, the one `bottles-cli add` generated, so it can
      # only be read back out of the bottle. No program registered, no library entry.
      id="$(gawk -v want="        name: $program" '
        /^External_Programs:/ { blk = 1; next }
        /^[A-Za-z]/ { blk = 0 }
        blk && /^    [0-9a-f-]+:$/ { id = substr($1, 1, length($1) - 1) }
        blk && $0 == want { print id; exit }
      ' "$yml")"
      [ -n "$id" ] || exit 0

      # The UUID is the identity and the name is not: the same game can sit in two bottles.
      if [ -f "$lib" ] && grep -qxF "  id: $id" "$lib"; then
        exit 0
      fi

      bottleName="$(sed -n 's/^Name: //p' "$yml")"
      # A DOUBLE-quoted YAML scalar, which carries an apostrophe with no escaping at all.
      quote() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

      # `{}` is what Bottles writes for an empty library, and appending after it is invalid YAML.
      if [ ! -s "$lib" ] || [ "$(tr -d '[:space:]' < "$lib")" = "{}" ]; then
        : > "$lib"
      fi

      # THE COVER comes from Bottles' own proxy, the endpoint its GUI calls. BEST EFFORT on
      # purpose: no art is a text tile, and a rebuild must never hang on somebody's CDN.
      thumb=""
      endpoint="https://steamgrid.usebottles.com/api/search/$(jq -rn --arg s "$program" '$s|@uri')"
      if raw="$(curl -fsS --max-time 8 "$endpoint" 2>/dev/null)"; then
        url="$(printf '%s' "$raw" | jq -r 'if type == "string" then . else empty end' 2>/dev/null || true)"
        if [ -n "$url" ]; then
          # The extension comes off the URL, and anything unexpected is treated as a png.
          case "''${url##*.}" in
            png | jpg | jpeg | webp) ext="''${url##*.}" ;;
            *) ext=png ;;
          esac
          file="$(cat /proc/sys/kernel/random/uuid).$ext"
          grids="${bottlesDir}/$dir/grids"
          mkdir -p "$grids"
          if curl -fsS --max-time 20 -o "$grids/$file" "$url" 2>/dev/null && [ -s "$grids/$file" ]; then
            thumb="grid:$file"
          else
            rm -f "$grids/$file"
          fi
        fi
      fi

      {
        printf '%s:\n' "$(cat /proc/sys/kernel/random/uuid)"
        printf '  bottle:\n'
        printf '    name: "%s"\n' "$(quote "$bottleName")"
        printf '    path: "%s"\n' "$(quote "$dir")"
        printf '  icon: ""\n'
        printf '  id: %s\n' "$id"
        printf '  name: "%s"\n' "$(quote "$program")"
        if [ -n "$thumb" ]; then
          printf '  thumbnail: "%s"\n' "$thumb"
        else
          printf '  thumbnail: null\n'
        fi
      } >> "$lib"
    '';
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
            # `--launch-options=` and NEVER `-l`: argparse reads a value starting with `--` as
            # another option, and every Battle.net command line here starts with one.
            run ${bottlesApp}/bin/bottles-cli add -b "$(sed -n 's/^Name: //p' "$yml")" \
              -n ${lib.escapeShellArg name} -p ${lib.escapeShellArg p.path} \
              ${lib.optionalString (p.arguments != "") "--launch-options=${lib.escapeShellArg p.arguments}"}
          fi
          # THE LIBRARY IS A SEPARATE FILE from the bottle's program list, and this is the half
          # that puts the tile in the Library tab. Idempotent, so it runs unconditionally.
          run ${lib.getExe libraryAdd} ${lib.escapeShellArg p.dir} ${lib.escapeShellArg name}
        '') config.my.games.library
      )
    );
  };
}
