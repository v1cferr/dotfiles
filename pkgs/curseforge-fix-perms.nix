# curseforge-fix-perms: gives back the exec bit that the CurseForge extractor drops on
# everything it unpacks under `minecraft/Install`. It fixes an APP BUG, not a NixOS quirk:
# on no distro would those binaries run.
#
# WHAT HAPPENS (measured on 15/08/2026, agent 1.316.0-37372): the app unpacks what it
# downloads with a .NET extractor that does NOT preserve permissions, so every file lands
# `rw-r--r--`. Whatever the app later tries to `exec` dies with `Permission denied`, and the
# app never says so: it fails to map its own internal error (`Invalid enum value: General`,
# in `background.js`) and falls back to the generic red banner, "An unexpected error
# occurred. Operation failed.". That banner points at nothing, which is the expensive part.
#
# THIS FILE WAS BORN AS `curseforge-fix-java` AND THE NAME DESCRIBED A SYMPTOM. On 14/08/2026
# the visible damage was the JRE the app downloads
# (`OpenJDK21U-jre_x64_linux_hotspot_21.0.4_7.tar.gz`, into `Install/java/`): its 6 `bin/`
# binaries and 37 `.so` came out 644, the first `java -version` died with
# `System.ComponentModel.Win32Exception`, and the app concluded, to my face, "Java Runtime
# Environment is missing or out of date". So the script covered `Install/java` and nothing
# else. On 15/08/2026 Minecraft still refused to open, and the agent log named a different
# victim:
#     [Radiuminator] Failed to launch Minecraft instance: d967e030-...
#       An error occurred trying to start process
#       '.../Documents/curseforge/minecraft/Install/minecraft-launcher'
#       with working directory '.../Install'. Permission denied.
# A sweep of `Install/` by ELF magic byte found 115 ELF files still at 644:
#     runtime/ 68 (the JRE of the VANILLA launcher, the one that actually runs the game)
#     natives/ 31 (lwjgl/openal per modloader)   launcher/ 8 (the launcher CEF)
#     bin/ 6 (natives per version)   webcache2/ 1 (widevine)   minecraft-launcher itself
# and `java/` was the ONLY correct tree, 133 of 133, precisely because that was what the old
# script covered. The extractor loses the bit on EVERYTHING, so the fix follows it there.
#
# WHY ELF MAGIC BYTE AND NOT A LIST OF NAMES (which is what the java-only version did, with
# `-path '*/bin/*' -o -name '*.so'`): the tree grows on its own. Each new MC version brings a
# `bin/<hash>/`, each modloader brings a `natives/<name>-<version>/`, and a name list has to
# guess the next binary's name. Reading 4 bytes answers it without guessing, and bash reads
# them itself, so there is no `file` and no fork per candidate.
#
# WHY `assets/` IS PRUNED: it is the only subtree that grows without bound (8879 files with a
# single modpack installed, and it multiplies per MC version), and it holds Mojang's
# content-addressed blobs, `objects/<2 hex>/<sha1>`, which are textures, sounds and lang
# files. Nothing there is ever executed. Pruning it takes the sweep from ~1.0s to ~0.2s on
# EVERY activation, which is what pays for the assumption.
#
# WHY `Instances/` IS OUT OF SCOPE, even though there are two 644 `.so` in there today
# (`libEffekseerNativeForJava.so` and `epicfight/.../ServerCommunicationHelper.so`): those are
# unpacked from their own jars by the MODS, at runtime, 644 on every distro, and `dlopen`
# does not look at the exec bit. That is not a lost bit, it is how those mods ship. Touching
# them would be fighting the mod on every launch.
#
# THE `.so` UNDER `Install/` DO GET +x for the opposite reason: `dlopen` does not need it
# there either, but the original tarballs ship them 755, so restoring what the extractor lost
# is more defensible than judging one by one which ones would load anyway.
#
# IT DOES NOT HEAL ITSELF: trying to reinstall the JRE to fix it, the extraction fails at
# `The file '.../Jre_21/NOTICE' already exists.`, because the extractor does not overwrite
# either. So the "Retry" button in the interface loops forever without moving. Without this
# script the app stays stuck, and the only visible symptom is still the wrong one.
#
# DO NOT TRY TO FIX IT WITH DECLARATIVE JAVA (the obvious attempt, and the WRONG one):
# putting `java` in the FHS PATH does nothing, because the app only consults the JRE it
# manages itself. With three JREs installed the agent log went on citing ITS java 18 times and
# ours ZERO times. That is why pkgs/curseforge.nix has no Java in it, and why this exists.
#
# WHERE IT RUNS: in the home-manager activation (home/apps/curseforge.nix), on every rebuild,
# and by hand when the app downloads something new in the middle of a session. It is
# idempotent: with nothing to fix it writes nothing and says nothing.
{
  writeShellApplication,
  findutils,
  coreutils,
}:

writeShellApplication {
  name = "curseforge-fix-perms";
  runtimeInputs = [
    findutils
    coreutils
  ];

  # set -euo pipefail already comes from writeShellApplication (default bashOptions).
  text = ''
    # Path by ARGUMENT with a default, so it is testable without touching the real tree.
    root="''${1:-$HOME/Documents/curseforge/minecraft/Install}"
    root="''${root%/}" # a trailing slash would break the -path of the prune below

    # Silence when the app has not downloaded anything yet: this runs on EVERY activation,
    # and warning about a normal absence would become noise nobody reads anymore.
    [ -d "$root" ] || exit 0

    broken=()
    while IFS= read -r -d "" file; do
      # The 4-byte ELF magic, read by bash itself. `|| true` because `read` reports failure
      # on a file shorter than 4 bytes, and `set -e` would take that as the script failing.
      magic=""
      IFS= read -r -n4 magic < "$file" 2>/dev/null || true
      if [ "$magic" = $'\x7fELF' ]; then
        broken+=("$file")
      fi
    done < <(find "$root" -path "$root/assets" -prune -o -type f ! -perm -u+x -print0)

    [ ''${#broken[@]} -gt 0 ] || exit 0

    chmod +x "''${broken[@]}"
    echo "curseforge-fix-perms: +x on ''${#broken[@]} file(s) under $root"
  '';

  meta = {
    description = "Restores the exec bit that the CurseForge extractor drops on what the app downloads";
    mainProgram = "curseforge-fix-perms";
  };
}
