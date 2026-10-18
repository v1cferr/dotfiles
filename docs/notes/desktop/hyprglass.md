# HyprGlass: Perceptible Glass, declarative and off until switched on

`pkgs/hyprglass/package.nix` (the build), `modules/home/desktop/hyprglass.nix` (the switch and the
path handed to the Lua) and `modules/home/desktop/hypr/lua/glass.lua` (the load and the presets).
[HyprGlass](https://github.com/hyprnux/hyprglass) is a Liquid Glass plugin for Hyprland: blur, a
tint and refraction at the rim of a window or a layer, so what is behind it reads as shapes and
color while the front stays legible. Added on 17/10/2026, and **off by default**
(`my.hypr.hyprglass.enable = false`): turning it on loads a plugin into the running compositor,
which is the one step that can take the session down, so that step is the owner's to take, with the
procedure below.

## Versions, and why this build matches

| Piece | Version | Where it comes from |
| --- | --- | --- |
| Hyprland (the session) | 0.56.2, commit `efb50993` | `programs.hyprland.package = pkgs.unstable.hyprland` |
| HyprGlass | 0.10.0, commit `84c1a5ab` | `fetchFromGitHub`, the commit pinned with its hash |
| hyprutils / hyprlang / aquamarine / glibc | 0.14.2 / 0.6.8 / 0.15.1 / 2.44 | the same store paths in both closures |

**v0.10.0 is the release upstream pins to this exact Hyprland.** Upstream's `hyprpm.toml` on `main`
maps Hyprland 0.56.2's commit `efb50993` to HyprGlass `84c1a5ab`, v0.10.0 (the v0.10.0 tag's own
copy still pointed 0.56.2 at v0.8.1; the pin moved with the release). The number matching was not
taken as proof: the plugin is built by nixpkgs' `hyprlandPlugins.mkHyprlandPlugin` against the
`hyprland` it is given, and the module re-pins that to `osConfig.programs.hyprland.package`, the
session's own. The built `.so` references `hyprland-0.56.2` at `y4n3...`, the store path the session
runs, and its hyprutils, hyprlang, aquamarine and glibc are the same store paths as the compositor's.
v0.10.0 also refuses to draw ("pauses") on a Hyprland it was not built for, instead of crashing.

**Not hyprpm, not a loose `.so`.** hyprpm builds imperatively into the user's state and a downloaded
release is a binary nobody pinned; both break rule 3. The derivation is in the flake, so the gate
builds it and the lock pins it (rule 13).

**The hyprctl skew found on the way.** The session runs the UNSTABLE Hyprland while four Home
Manager modules took `hyprctl` from the stable `pkgs.hyprland`, 0.55.4. They take the session's
package now (commit `e4d7538e`).

## How it loads

`glass.lua` runs before `appearance.lua`. It reads `~/.config/theme/plugins.lua`, which the module
generates with the plugin's path when it is on and `nil` when it is off, and:

1. declares the plugin with `hl.plugin.load(path)` on EVERY pass in which Nix names it (below: a
   "load it only once" guard is what crashed the session on 17/10/2026);
2. configures it ONLY inside `if hl.plugin.hyprglass then`, upstream's guard, so a missing or paused
   plugin skips the whole block instead of producing config errors;
3. returns early when the plugin is absent, so the native blur stays in charge.

**The plugin list is DECLARATIVE, and getting that wrong crashed the session.** On 17/10/2026, the
`rebuild` that switched it on made Hyprland reload its config, and Hyprland died with SIGSEGV; the
crash handler's restart died the same way, and `start-hyprland` came back on its recovery config
(`recoverycfg.lua`, no binds, no rules). The core dump showed `reload` -> `postConfigReload` ->
`handlePluginLoads` -> `reload` again, until the stack overflowed. Hyprland 0.56.2's
`CPluginSystem::updateConfigPlugins` compares the plugins declared in THIS pass of the config with
the ones it has: it loads what is new, UNLOADS what a pass no longer declares, and reloads the config
when anything changed. The first `glass.lua` loaded the plugin only "if not loaded yet", so pass 1
declared it (load, reload), pass 2 skipped it (unload, reload), pass 3 declared it again, forever.
Every pass now declares it while Nix names it, so the list is the same on every pass and the second
pass is a no-op.

Why the earlier tests missed it: their test config called `hl.plugin.load` itself, unconditionally,
before `glass.lua`, so the declared list never changed. The fix was tested with `glass.lua` ALONE
as the live config runs it: the unfixed file reproduced the crash in the nested compositor (the same
`handlePluginLoads` recursion in its core dump), and the fixed one came up with the plugin `active`,
then survived five `hyprctl reload`s with one plugin loaded.

**A crash that is NOT the plugin's:** a nested Hyprland killed with SIGTERM while windows are open
segfaults in `CCompositor::cleanup` (unmapping a window), with or without the plugin; a nested run
with no plugin at all did the same. Every nested test of the day ended that way, which is why a core
dump at a nested test's teardown says nothing about HyprGlass.

**The startup hang upstream warns about does not apply here.** A plugin load makes Hyprland run the
whole Lua file once more during startup, and a top-level `os.execute`, `io.popen` or `hyprctl` then
blocks forever. Checked on 17/10/2026: no module does any of that at the top level; every command
is inside a bind or `hl.on("hyprland.start")`.

**One blur, never two.** With the plugin active, `appearance.lua` does not add its native blur rule
to the shell's layers: HyprGlass takes them, and the plugin itself sets `noblur` on the windows it
glasses (`manage_window_blur`, its default). With it off, the native rule from
[theme.md](theme.md#the-blur-and-solid) is back exactly as before.

## The presets

Three presets, all on upstream's `subtle`, all with documented options only. Their numbers come from
the glass PROFILE (`my.theme.glass`): the `V` table at the top of `glass.lua` holds the only values
that differ between `perceptible` and `clear-gradient`, both listed in
[theme.md](theme.md#the-two-profiles-18102026). The values below are `perceptible`'s.

| Preset | Used by | What it changes |
| --- | --- | --- |
| `window` | every window that is not opaque; under `clear-gradient`, every shell layer too, so the desktop is one material | `xray = 0` (the windows behind stay visible: that is the depth), no self sampling, blur 1.2, refraction 0.3 kept to the rim (`refraction_spread = 0.2`), no lens dome, no chromatic aberration, specular 0.15, fresnel 0.2, the palette's bg as tint at about a third |
| `ui` | the bar and the band, under `perceptible` | more blur (1.6), almost no refraction (0.12), a thin edge, since text runs across the whole surface |
| `panel` | panels, the NixOS Center, toasts, under `perceptible` | the most blur (2.0) and a darker tint, since they are read the longest |

**Every window, except fullscreen and games** (since 18/10/2026; before, only kitty and floating
windows had it, by tag). The global switch is on and the plugin skips what is opaque
(`skip_opaque_windows`): Dolphin and the other Kvantum apps are opaque by design
([theme.md](theme.md)). A browser or an editor sits at the global 0.98 opacity, so its glass is there
but barely shows: Hyprland's window opacity fades the text along with the background, and only an
app that draws its own translucent background (kitty) can show more without losing contrast. Tagged
off: Hearthstone, Overwatch, Steam games, Picture-in-Picture and Flameshot's overlay. Layer glass
covers `qs-bar`, `qs-dash` (the LG's band), `qs-panel` (panels, toasts, the OSD, the band's
tooltips) and `qs-center` at a 0.5 alpha mask, so the shell's transparent gaps get no glass.

**Fullscreen is an event, not a rule**, and both rules were measured in the nested session on
0.56.2. `match = { fullscreen = true }` also matches the MAXIMIZED state (1) a lone scrolling column
has at map (`scrolling.fullscreen_on_one_column`), so it tagged nearly every window; `match = {
fullscreen_state_internal = 2 }` caught only a real fullscreen, but its tag stayed after leaving it,
through a focus change, a float toggle and a reload, so the window would lose its glass for good. So
`glass.lua` listens to `window.fullscreen` and adds the static `hyprglass_disabled` tag at state 2,
removing it otherwise. Removing the static tag leaves a game rule's dynamic one (`hyprglass_disabled*`)
in place: measured on a window holding both.

## How it was verified without touching the session

The live compositor never loaded the plugin. Every test ran in a NESTED Hyprland, the same binary,
inside a temporary headless output of the live one (`hyprctl output create headless`), torn down
after each run; a nested Hyprland needs `xdg_wm_base` v6, which a headless sway 1.12 does not offer.
Inside it, a translucent kitty over colored rows and a floating translucent kitty on top.

| Check | Result (17/10/2026) |
| --- | --- |
| `hyprctl plugin list` | `hyprglass 0.10.0` loaded |
| `hyprctl hyprglass status` | `active`, `version check: match`, `shaders: ready`, windows on, layers on |
| `hyprctl configerrors` with the repo's `glass.lua` | empty: every option and preset name accepted |
| `hyprctl hyprglass stats` over 3 s | 1 window draw per frame for 181 frames, all 181 from the background cache, 0.299 glass Mpx per frame |
| the live session after each run | one instance, DP-1 and DP-2 only, `no plugins loaded` |

What this does NOT prove: how it looks at the desk on the real monitors (the nested output ran at
its own scale), how it behaves on the rotated LG with the shell's layers, and what it costs on the
GPU. Those need the owner's eyes and the procedure below.

## Turning it on, and back off

1. **Save your work.** This is the step that can crash the compositor.
2. In `hosts/ex-b560m-v5/default.nix`:
   `home-manager.users.v1cferr.my.hypr.hyprglass.enable = true;`
3. `! rebuild`, then `hyprctl reload`: the reload runs `glass.lua`, which loads the plugin.
4. Check: `hyprctl hyprglass status` says `active` and `version check: match`;
   `hyprctl configerrors` is empty; open a kitty over a colorful window.
5. Tune at the desk: every value is a line in `glass.lua`, and a reload applies it.

**Back off, in order of urgency:**

- **Now, no rebuild:** `hyprctl plugin unload <path>`, the path being the one `plugins.lua` names
  (`grep hyprglass ~/.config/theme/plugins.lua`). Tested in the nested session: `no plugins loaded`
  after it, the compositor and its windows still up, no config errors.
- **For good:** set the option back to `false`, `! rebuild`, `hyprctl reload`; the native blur
  returns, since `glass.lua` returns early.
- **If Hyprland will not start** with it: from a TTY (Ctrl+Alt+F2) or SSH,
  `sudo nixos-rebuild switch --rollback` restores the previous generation, whose `plugins.lua` names
  no plugin; or start Hyprland with `--safe-mode`. Older generations are never deleted by this.

## Rejected

- **Turning it on by default in the same commit.** The nested test proves load and draw, not the
  session; loading into the compositor the owner is working in is the owner's call.
- **hyprpm or a downloaded `.so`**: imperative, unpinned (above).
- **Glass on every window** with a global opacity: the brief ruled it out, and most windows here are
  opaque on purpose.
- **Native blur under HyprGlass**: two blurs stacked, for no gain anyone could show.
