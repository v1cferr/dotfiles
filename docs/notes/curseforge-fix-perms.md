# curseforge-fix-perms

Module: [`pkgs/curseforge-fix-perms.nix`](../../pkgs/curseforge-fix-perms.nix)

Gives back the exec bit that the CurseForge extractor drops on everything it unpacks under
`minecraft/Install`. It fixes an APP BUG, not a NixOS quirk: on no distro would those binaries
run.

## What happens

Measured on 15/08/2026, agent 1.316.0-37372. The app unpacks what it downloads with a .NET
extractor that does NOT preserve permissions, so every file lands `rw-r--r--`. Whatever the app
later tries to `exec` dies with `Permission denied`, and the app never says so: it fails to map
its own internal error (`Invalid enum value: General`, in `background.js`) and falls back to the
generic red banner, "An unexpected error occurred. Operation failed.". That banner points at
nothing, which is the expensive part.

It does not heal itself either. Reinstalling the JRE to fix it fails at
`The file '.../Jre_21/NOTICE' already exists.`, because the extractor does not overwrite, so the
"Retry" button loops forever without moving.

## It was born as `curseforge-fix-java`, and the name described a symptom

On 14/08/2026 the visible damage was the JRE the app downloads
(`OpenJDK21U-jre_x64_linux_hotspot_21.0.4_7.tar.gz`, into `Install/java/`): its 6 `bin/` binaries
and 37 `.so` came out 644, the first `java -version` died with
`System.ComponentModel.Win32Exception`, and the app concluded, to my face, "Java Runtime
Environment is missing or out of date". So the script covered `Install/java` and nothing else.

On 15/08/2026 Minecraft still refused to open, and the agent log named a different victim:

```text
[Radiuminator] Failed to launch Minecraft instance: d967e030-...
  An error occurred trying to start process
  '.../Documents/curseforge/minecraft/Install/minecraft-launcher'
  with working directory '.../Install'. Permission denied.
```

A sweep of `Install/` by ELF magic byte found **115 ELF files still at 644**:

| Tree | Files | What it is |
| --- | --- | --- |
| `runtime/` | 68 | the JRE of the VANILLA launcher, the one that actually runs the game |
| `natives/` | 31 | lwjgl/openal per modloader |
| `launcher/` | 8 | the launcher CEF |
| `bin/` | 6 | natives per version |
| `webcache2/` | 1 | widevine |
| `minecraft-launcher` | 1 | itself |

And `java/` was the ONLY correct tree, 133 of 133, precisely because that was what the old script
covered. The extractor loses the bit on EVERYTHING, so the fix follows it there.

## Why ELF magic byte and not a list of names

The java-only version matched `-path '*/bin/*' -o -name '*.so'`. The tree grows on its own: each
new MC version brings a `bin/<hash>/`, each modloader brings a `natives/<name>-<version>/`, and a
name list has to guess the next binary's name. Reading 4 bytes answers it without guessing, and
bash reads them itself, so there is no `file` and no fork per candidate.

## Why `assets/` is pruned

It is the only subtree that grows without bound (8879 files with a single modpack installed, and
it multiplies per MC version), and it holds Mojang's content-addressed blobs,
`objects/<2 hex>/<sha1>`, which are textures, sounds and lang files. Nothing there is ever
executed. Pruning it takes the sweep from ~1.0s to ~0.2s on EVERY activation, which is what pays
for the assumption.

## Why `Instances/` is out of scope

There are two 644 `.so` in there today (`libEffekseerNativeForJava.so` and
`epicfight/.../ServerCommunicationHelper.so`). Those are unpacked from their own jars by the
MODS, at runtime, 644 on every distro, and `dlopen` does not look at the exec bit. That is not a
lost bit, it is how those mods ship. Touching them would be fighting the mod on every launch.

The `.so` under `Install/` do get `+x` for the opposite reason: `dlopen` does not need it there
either, but the original tarballs ship them 755, so restoring what the extractor lost is more
defensible than judging one by one which ones would load anyway.

## Do not try to fix it with declarative Java

That is the obvious attempt and the wrong one. Putting `java` in the FHS PATH does nothing,
because the app only consults the JRE it manages itself. With three JREs installed the agent log
went on citing ITS java 18 times and ours ZERO times. That is why
[`pkgs/curseforge.nix`](../../pkgs/curseforge.nix) has no Java in it, and why this script exists.

## Where it runs

In the home-manager activation ([`home/apps/curseforge.nix`](../../home/apps/curseforge.nix)), on
every rebuild, and by hand when the app downloads something new in the middle of a session. It is
idempotent: with nothing to fix it writes nothing and says nothing.
