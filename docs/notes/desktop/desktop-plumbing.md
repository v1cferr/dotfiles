# Desktop plumbing: the polkit agent, XDG associations, the wallpaper, rofi

Small modules whose reasoning is longer than their config.

## The polkit agent

`home/desktop/polkit-agent.nix`. What shows the password dialog when a GRAPHICAL app needs
authorization: mounting another user's disk, writing to a block device, controlling a systemd unit
from the GUI.

**The gap this closes (01/08/2026)**: `polkitd` was running, but there was NO agent at all. The
daemon alone only decides "allowed / not allowed" through the rules; what asks the human for the
password is the agent. Without it, every action requiring `auth_admin` failed SILENTLY: the app
asked for authorization, nobody answered, and the user only saw "permission denied" with no prompt.
Discovered trying to elevate `woeusbgui`, but the hole was general.

**Why hyprpolkitagent**: it is the Hyprland ecosystem's (Qt6/QML), it matches the Qt/Kvantum desktop
here, and upstream already ships a ready systemd unit. It is rewritten in Nix so there is ONE OWNER
(rule 14) instead of depending on the package's file.

**A known trap, `graphical-session.target`**: in many Hyprland+NixOS setups that target stays
INACTIVE and everything depending on it silently does not come up (home-manager#8547). Here it is
active, the same mechanism that raises this repo's `autostart-*` units, so the default `WantedBy`
works. If the autostarts ever stop coming up, this agent stops with them, and the symptom will be
"the password prompt disappeared", which does not look like a target problem.

Three details: `ConditionEnvironment = WAYLAND_DISPLAY` makes it a clean no-op outside a Wayland
session instead of restarting against a display that does not exist; the binary lives in `libexec/`
and not `bin/`, so `getExe` does not find it; and `Slice = session.slice` makes it die with the
session instead of becoming an orphan.

To check: `systemctl --user status hyprpolkitagent`.

## XDG associations

`home/desktop/xdg.nix`. Nothing is INSTALLED here (the Zen package comes from the flake, in
`system/`). It only ASSOCIATES: which `.desktop` opens what.

`xdg.mimeApps` writes `~/.config/mimeapps.list` (managed, read-only), and that is what
`xdg-settings get default-web-browser` and the GTK/Electron apps consult. Zen's `.desktop` is
`zen-beta.desktop`. Check with `xdg-mime query default x-scheme-handler/https`.

`home.sessionVariables.BROWSER` closes the case of the terminal apps (git, gh, the `xdg-open` CLI)
that ignore mimeapps and read the env var instead.

**Text and code go to VS Code.** Without those lines a double click fell into Okular, which claims
`text/plain` and markdown in its `.desktop`, or into NOTHING, since json/csv/yaml/toml/py/js had no
handler at all. One oddity worth keeping: `.ts` is `text/vnd.trolltech.linguist`, because
shared-mime-info matches Qt Linguist and not TypeScript.

### `applications.menu`: without it, KDE apps open NOTHING on a double click

KF6 apps (Dolphin, Gwenview, Okular, Ark) resolve "who opens this file" through
`KApplicationTrader`, which reads the ksycoca index. And `kbuildsycoca` only discovers the
`.desktop` files by walking the XDG menu (`applications.menu`), so without that file it indexes
ZERO applications and the double click fails in silence, even with a perfectly fine
`mimeapps.list`. The journal says "applications.menu not found in …".

Plasma would bring its own (`plasma-applications.menu`), but here the session is Hyprland, so it
has to be declared. A flat menu (`<All/>`) because the only consumer is the ksycoca index, not a
launcher with categories: rofi reads the `.desktop` files directly. If Plasma ever comes in, it
uses the `XDG_MENU_PREFIX=plasma-` prefix and ignores this file, so there is no conflict.

## The wallpaper

`home/desktop/wallpaper.nix`. hyprpaper (Hyprland's official daemon: static, light, declarative).
The images come through `pkgs.nixos-artwork`, so no binary in git and they bump with nixpkgs. The
main one is catppuccin-mocha and the secondary is waterfall, the SAME two as the lockscreen, so
unlocking does not change the background underneath.

Both images are 3840x2160, and the secondary stands on its pivot, so hyprpaper covers 1080x1920 by
keeping the CENTRAL 32% of the width. That is why the choice there is a waterfall: the subject runs
along the axis that survives the crop. Any of the gradients would do as well, for the opposite
reason, since they have no subject to lose.

**The config format (hyprpaper 0.8.x) is why the screen went BLACK.** 0.8 swapped the flat format
(`wallpaper = MONITOR,path` plus `preload =` plus `ipc =`) for a CATEGORY
(`wallpaper { monitor = …; path = …; }`). `preload` and `ipc` do not even exist in the binary
anymore: `strings hyprpaper | grep -c preload` gives 0.

With the old format hyprpaper COMES UP, finds the monitors, and logs "Monitor DP-2 has no target:
no wp will be created". No layer surface is created and the background stays black, with no parse
error to give away the reason.

home-manager's `services.hyprpaper` module still generates the OLD format, so the config is written
here through `xdg.configFile` and the module comes in only with `enable`, providing the
`systemd --user` service and the package. If the module ever learns the new format, this goes back
into `settings` and the file gets shorter.

**Why `pathOf` reads the directory instead of building the string**: the FILE name inside the
package does NOT follow a pattern. Most are `nix-wallpaper-<attr>.png`, the catppuccin ones are
`nixos-wallpaper-<attr>.png`, and gradient-grey is `NixOS-Gradient-grey.png`. Building the path by
string would break on a swap, and that is exactly what made the "switching = 1 line" comment a lie.
The options are in
`nix eval nixpkgs#nixos-artwork.wallpapers --apply builtins.attrNames`, about 30 of them.

## The keybind cheatsheet

`home/desktop/cheatsheet.nix`. A rofi list of ALL the Hyprland binds, on SUPER+H.

**GENERATED from `keybinds.lua` at RUNTIME, never written by hand**: a duplicated list would become
a lie on the first new bind. The file it reads is `~/.config/hypr/lua/keybinds.lua`, which is a
`mkOutOfStoreSymlink` into the repo, so the cheatsheet even follows a hot-reload edit with no
rebuild.

**Why SUPER+H and not SUPER+/**: Moonlight does NOT send the ABNT2 "/ ?" key (bug #1789, the same
reason as the ScrollLock remap in `keybinds.lua`), so SUPER+/ would die over remote access. H is
free and gets through on any path.

The rofi package comes from `clipboard.nix`; do not redeclare it, since it is the same tool for the
launcher, the clipboard and here.

### The awk parser's rules

All dictated by `keybinds.lua`'s real format:

- the GROUP is the first line of the comment block right ABOVE the bind;
- the DESCRIPTION is the comment at the END of the bind's line, falling back to the group's text;
- binds inside `hl.define_submap` get a submap prefix, otherwise `1`/`2`/`Esc` would show up loose
  and meaningless in the list.

Two details that broke earlier versions and are therefore explicit:

1. the comment is found by the LAST `" -- "` on the line, not by a "no hyphen" regex, because
   legitimate descriptions contain a hyphen ("no-op", "qs-restart") and were disappearing;
2. the keys are translated TOKEN BY TOKEN (`comma` to `,`), not with a blind gsub, otherwise the
   "left" inside "mouse_left" would be substituted too.

`short()` cuts only at the first `". "` and never at `": "`, since groups like "Mouse: move /
resize the window" would become the useless "Mouse".

The script fails LOUDLY if the symlink disappears, because an empty cheatsheet would lie by saying
"there are no binds". And it only DISPLAYS: the choice is discarded, since it is a reference and
not an action runner.

Two rasi notes: an explicit `font` is needed or rofi falls back to "mono 12", and `my.fonts.ui` is
also the system monospace so the columns line up. Do NOT comment inside a `.rasi` with `#`: there
`#` opens a color literal and breaks the parse.

## The clipboard and the launcher

`home/desktop/clipboard.nix` and `launcher.nix`. Both are rofi, and the rofi PACKAGE is declared
once, in `clipboard.nix`. Do not redeclare it: it is the same tool for the launcher, the clipboard
and the cheatsheet.

**The clipboard** is cliphist storing text, images and URIs through its declarative service
(`allowImages` also brings up the image watcher on top of the text one), with rofi `-show-icons` as
the picker. It replaced the old wofi picker, which was text only. The bind is SUPER+SHIFT+V.

Migrated from Arch (`cliphist-rofi-img.sh`) WITH an improvement: besides the image thumbnail,
copied files (a `file://…` URI) now get an ICON for their type (zip, video, pdf) resolved by the
active icon theme. Rules 1 and 3: idiomatic and declarative.

`clipboard-menu` does one pass (list, rofi, decode, copy) and builds the rofi entry as
`line\0icon\x1f<icon>` per item, in three cases:

- a binary image gets decoded into a cache directory once and used as a THUMBNAIL;
- a `file://` URI gets a NAMED freedesktop icon derived from the extension;
- anything else gets the text icon.

### clipboard-push: the clipboard onto a remote host

`clipboard-push [host|local]` (SUPER+ALT+V, and the destination defaults to `workstation`) sends
what is in the clipboard over scp and leaves the ABSOLUTE REMOTE PATH in the clipboard. With `local`
it skips the network and drops the file in `~/.cache/clipboard-push` instead, which is the half the
kitten below uses when the window is not an ssh. It exists for one
workflow: Claude Code running on the FAI workstation over ssh reads THAT machine's filesystem and
cannot see this one's clipboard, so an image only reaches it as a path.

**An image wins, a copied file is the fallback.** `wl-paste --list-types` decides: the first
`image/*` becomes `clip-<timestamp>.<ext>`, and failing that a `file://` URI (what Dolphin leaves
in the clipboard) goes up under its own basename. The URI is percent-decoded, because a name with a
space arrives as `a%20b.png` and would land as a file nobody can find.

**The remote half goes in through ssh's STDIN**, the same trick as `wake-workstation`
([fai-workstation.md](../network/fai-workstation.md)), for the same reason: the workstation is
somebody else's Ubuntu and nothing may be installed on it. That one connection does three things:
it creates `~/.cache/clipboard-push`, deletes what is older than a week, and prints `$HOME`
RESOLVED, which is what scp and the TUI both need, since a `~` pasted into a prompt is not expanded
by whatever reads it. The prune shares the pass on purpose: a drop that only grows, on a machine
that is not mine, is the kind of mess nobody comes back to clean.

**`wl-copy` gets the path with NO trailing newline**, and that is the detail the flow lives on: a
newline pasted into a TUI SUBMITS the prompt instead of typing into it.

It costs one handshake and not two, because the `workstation` block in `home/shell/ssh.nix` sets
`ControlMaster auto`: the scp reuses the master the ssh above opened. And the image is not lost when
the path takes its place in the clipboard, since cliphist still holds it, one SUPER+SHIFT+V away.

### ctrl+shift+v decides, and the kitten is how

`home/shell/kitty/smart-paste.py`, bound to `ctrl+shift+v` in `home/shell/kitty.nix`. Two keys for
one intention was the wrong shape: push with SUPER+ALT+V, then paste, and remember which window was
an ssh and which was not. The terminal already knows, so the kitten asks it.

**The divergence is narrow ON PURPOSE.** Only an IMAGE in the clipboard takes the new path, and
everything else falls through to kitty's own paste, with the bracketed paste, the `paste_actions`
filters and the large-paste confirmation that come with it. The most used key on this machine is the
wrong place to reimplement pasting. SUPER+ALT+V is still what pushes a copied FILE, which the kitten
ignores deliberately.

**The destination comes from the window's FOREGROUND PROCESS** (`window.child.foreground_processes`,
the same data `kitty @ ls` prints). An `ssh` there means the destination is its host, parsed by
skipping the flags that swallow the next argument, where the test is the LAST letter: that is what
tells `-p 22`, a value follows, from `-p22`, attached. Anything else means `local`. What this cannot
see: an ssh started INSIDE the session (a second hop, tmux) and the `cesar` alias, whose
`RemoteCommand` is exactly why scp needs the `cesar-cmd` twin ([ssh.md](../network/ssh.md)).

**It never blocks kitty**, and this is the part that is easy to get wrong: `handle_result` runs IN
the kitty process, so a blocking scp would freeze the whole terminal for as long as the transfer
lasts, and for 14 s with the VPN down (`ConnectTimeout 7`, two attempts). The child is spawned
instead, and `boss.monitor_pid` does the paste when it dies. `no_ui=True` on the handler is what
keeps an overlay window from flashing: with it kitty skips `main()` and calls the handler in
process. `main()` still has to EXIST, since the loader reads it unconditionally.

**The paste targets the window the key was pressed in**, never the active one. After a transfer of a
couple of seconds those are not necessarily the same window, and a path pasted into whatever was
switched to in the meantime is worse than no paste at all.

**ctrl+alt+v stays bound to the plain paste**, because a kitten that breaks takes ctrl+shift+v down
with it, and rule 15's point about an automation with no fallback holds for a keystroke too.

MEASURED on 14/09/2026, driving a throwaway kitty over its own remote control: text pasted
unchanged; an image in a window running `ssh workstation` arrived on the workstation and pasted as
`/home/v1cferr/.cache/clipboard-push/clip-<stamp>.png`; the same image in a local shell landed in
`~/.cache` and pasted the local path. A Wayland trap showed up in the harness and not in the
feature: an UNFOCUSED window gets no selection offer, so `get_clipboard_string()` there is empty and
even kitty's own `paste_from_clipboard` pastes nothing.

**The launcher** is rofi `drun` with icons, sorted by most and recently used (rofi's history is on
by default: it shows the recent ones when it opens and filters fuzzily as you type). SUPER+Q is
apps, SUPER+R is binaries.

Both themes take their colors from `my.theme`, the single palette, so they recolor along when a
preset is switched, and their `icon-theme` comes from `my.theme.iconTheme`, the same one as the
system. The two `.rasi` caveats from the cheatsheet apply here as well: an explicit `font` is
required, and `#` inside a `.rasi` opens a color literal rather than a comment.
