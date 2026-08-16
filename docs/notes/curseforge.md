# curseforge

Module: [`pkgs/curseforge.nix`](../../pkgs/curseforge.nix)

The OFFICIAL Minecraft modpack app (Electron, by Overwolf). It replaced prismlauncher on
14/08/2026: Prism installs a CurseForge modpack by importing a `.zip`, without the library and
pack updating that are the whole reason the app exists.

It is NOT in nixpkgs (unfree and binary-only), so the repo repackages the official AppImage, the
same vendored-binary pattern as claude-desktop.

## Do not add Java here

It has been tried, and it is DEAD CONFIG (measured on 15/08/2026). The app DOWNLOADS and manages
its own JRE in `~/Documents/curseforge/minecraft/Install/java/`, and that is the only one it
consults: with `java` in the FHS PATH and three JREs in `/usr/lib/jvm`, the agent log went on
citing ITS java 18 times and ours ZERO times. All three went out in the same commit that brought
them in.

The "Java Runtime Environment is missing" error is NOT fixed from here: the cause is PERMISSIONS,
see [`curseforge-fix-perms`](curseforge-fix-perms.md).

## Shaders need zink, iris aborts the game

Turning on any Oculus shaderpack kills Minecraft with SIGABRT in under two minutes. There is no
crash-report and no Java exception, and the log just cuts mid-line, because the abort comes from
the video driver and not from the JVM. Measured on 15 and 16/08/2026, six coredumps.

All six carry the same stack: `abort()` reached from `_iris_batch_flush`, which in this release
build of Mesa 26.1.5 disassembles to a lone `call abort@plt`. That is the branch iris takes when
the kernel refuses the batch submission, and it takes the process down with no GL error to catch.
The call sites vary (`iris_transfer_map` while creating the pipeline, `st_TexSubImage` during
ordinary gameplay, `iris_fence_flush` on a context flush), which is what says compiling the
shaderpack is not special: any GPU work with shaders on eventually fails to submit.

The obvious suspects were measured, not guessed, and all cleared:

- `dmesg` is clean, so no GPU hang and no reset on the `xe` driver.
- The signal is SIGABRT, not the SIGKILL an OOM kill sends. earlyoom never fired.
- `vm.max_map_count` is 1048576 against 29259 mappings, counted from the `PT_LOAD` headers of the
  coredump.
- The card has 12 GiB of VRAM with ReBAR on.
- RAM is not it either, and this is what settles it: the zink run survives on 1274 MB of
  `MemAvailable` at its lowest, tighter than any iris crash had.

`MESA_LOADER_DRIVER_OVERRIDE=zink` swaps only the broken half of the stack. Same Mesa, same GPU,
same `xe` kernel driver, but OpenGL is translated to Vulkan and leaves through ANV, where Intel
actually puts its effort, instead of iris, the legacy GL path that is barely exercised on
Battlemage. See [`gpu.md`](gpu.md).

It goes in the derivation's `profile` and NOT in the `.desktop` because who needs the variable is
the JAVA the app spawns, not the Electron app. `buildFHSEnv` appends it to the `/etc/profile` of
the FHS and its init sources that file before `exec`, so every child inherits it. The scope stays
on this package on purpose: the rest of the system runs fine on iris and has no reason to carry a
workaround.

## Why AppImage and not the .deb

Both sources exist and are the SAME release. Everything that matters here is a binary the app
DOWNLOADS at runtime (the JRE, the Forge installer, Minecraft itself), and none of that goes
through `autoPatchelfHook`, which only reaches what is in the store.

This system's `programs.nix-ld` does cover the loader (the `/lib64/ld-linux` here points at it),
but not each one's libraries. The `buildFHSEnv` from appimageTools solves both at once and also
puts `/run/opengl-driver/lib` in the `ld.so.conf` (through `container-init.cc`), so Minecraft
inherits the FHS **and** the Arc B580 driver. It is the FHS that holds this package up, not
patchelf.

## The pointer URL

Overwolf only publishes `curseforge-latest-linux.AppImage`; there is no versioned URL (the
patterns `-1.316.0-`, `~37372` and `latest.yml` were all tested, all 404).

The `hash` in the module PINS the content, so the build is reproducible, but the day Overwolf
publishes the next version the fetch starts failing with a hash mismatch on a cold store, which is
exactly what VS Code's `/latest/` caused in the CI. Who pays that price is
[`curseforge-bump`](../../pkgs/curseforge-bump.nix), which runs on the `update` alias and rewrites
version and hash there. Do NOT swap it for `lib.fakeHash` or for a fetch with no hash (rule 13).

## The internal auto-updater does not work

`resources/app-update.yml` (gitlab provider) cannot do anything: the store is read-only. Updating
is `update`/`upgrade`, like everything else.

## Two details in the derivation

**`extract` plus `wrapAppImage`, not `wrapType2`** (which does both at once):
`extraInstallCommands` needs to READ the extracted tree to pick up the `.desktop` and the icons,
and `wrapType2` does not expose it.

**The `.desktop` is upstream's, with only `AppRun` swapped** for the FHS wrapper's name.

- `--no-sandbox` is NOT needed here. Measured on 14/08/2026 running `bin/curseforge`, which passes
  no flags at all: the app opens and loads the library normally, without the "SUID sandbox helper"
  this flag usually works around, because the bwrap from `buildFHSEnv` already gives Chromium the
  namespace it wants. It stays because it came from upstream and costs nothing; diverging from
  their `.desktop` would need a reason, and there is none.
- `%U` plus the `x-scheme-handler/curseforge...` MimeType entries are what make the "Install"
  button on the site open the app (a deep link). Declaring the scheme here is not enough: what
  says THIS `.desktop` is the default is
  [`home/apps/curseforge.nix`](../../home/apps/curseforge.nix), and without that the LOGIN does not
  come back.

The `version` string comes from the `X-AppImage-Version` of the `.desktop` inside the AppImage.
The `.deb` of the same release says `1.316.0~37372-37372`; the repeated `.37372` is
electron-builder noise.

## The user side

`home/apps/curseforge.nix`. The package (the official AppImage, repackaged) lives in
`pkgs/curseforge.nix`; this module is the home side.

**It REPLACED prismlauncher on 14/08/2026**: Prism imports a modpack `.zip`, but what keeps the
library and UPDATES the pack is the CurseForge app, which is the real use here.

And the swap SHRANK the system by 1.5 GiB, the opposite of what "native to Electron" suggests:
27.2 to 25.7 GiB, measured with `nix store diff-closures`. curseforge +340.2 MiB against
prismlauncher -17.6 MiB and openjdk (8, 17, 21 and 25, which the Prism wrapper bundled) -1.8 GiB.
The four JDKs left because NOBODY declares Java here: the provider is the app itself, which
downloads its own JRE.

Instances, mods and login are STATE (rule 6, so restic), not declaration: `~/.config/CurseForge/`
holds config plus session, `~/Documents/curseforge/` holds the instances.

The activation runs `curseforge-fix-perms` idempotently rather than managing files: the app is the
owner of what it unpacks (rule 14), so Nix only undoes a known bit of damage. `writeBoundary`
because the package has to be in the profile first. It is ALSO on the PATH, because the download
that breaks can happen IN THE MIDDLE of a session, by which point the activation has already run;
then it is a matter of running it by hand and reopening the app, with no rebuild to wait for.

### Why the schemes are declared here, and are not optional

The app tries to register itself as the handler for `curseforge://` and `cfauth://` at RUNTIME
(Electron's `setAsDefaultProtocolClient`), and that will NEVER work on this system:
`~/.config/mimeapps.list` is managed by home-manager and points into `/nix/store`, which is
read-only (rule 14, Nix is the owner). Measured on 14/08/2026, the app's log says exactly that on
startup:

```text
[BackgroundController] Failed subscribing app protocol.
[LoginService] Failed to register login scheme 'cfauth'. This might create issues
               with the login process..
```

And `cfauth://` is no detail: it is the LOGIN callback, since the app opens the browser and waits
for the redirect back. With no handler, the login comes back to nothing.

The declarative association is the registration the app cannot make on its own. The package's
`.desktop` already declares the three schemes in `MimeType`; the module only says that IT is the
default. The three are `cfauth` (the login callback, the one that matters most), `curseforge` (the
"Install" button on the modpack site) and `curseforge-checkout` (buying a premium add-on).
