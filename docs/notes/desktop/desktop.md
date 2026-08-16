# The desktop: Hyprland, autologin, portals, keyring

`system/desktop/desktop.nix`. A Wayland compositor. LightDM (an X11 greeter) launches the Hyprland
session; Xwayland covers X11 apps.

Careful: in a Wayland session the keyboard and the monitors do NOT come from the system's
xkb/xrandr. They are Hyprland config (`input.kb_layout` for ABNT2 and the `monitor=` lines for the
arrangement and the primary). The system's xkb here only covers the greeter and Xwayland apps.

`NIXOS_OZONE_WL = "1"` makes Electron/Chromium apps (vscode, spotify, chrome, claude-code) run
natively on Wayland instead of Xwayland.

## Autologin, and why it is not laziness

Sunshine (remote access) captures a LIVE graphical session, so with nobody logged in there is no
compositor to stream. With autologin the session comes up at boot, `graphical-session.target`
activates, and Sunshine (`autoStart`) comes up with it, so you can connect from Moonlight without
anybody touching the machine. A bonus: if Hyprland crashes, LightDM logs back in on its own.

`defaultSession` is MANDATORY (a lightdm assertion) and it defines which session the autologin
enters.

**The security trade**: the boot lands in an UNLOCKED session. The mitigation is hypridle locking
at 5 min (`home/desktop/lockscreen.nix`) plus remote access only through WireGuard. If you want it
locked right at boot, an `exec-once` of hyprlock in the autostart does it.

## The portals

`programs.hyprland` already enables `xdg.portal` plus `portal-hyprland` (screencast). Two more are
added:

- **portal-gtk** serves `org.freedesktop.appearance` (color-scheme), which is how Electron and
  Chromium apps (vscode, chrome, spotify) go dark along with the system.
- **portal-wlr** implements the Screenshot interface. portal-hyprland 1.3.12 only DECLARES it and
  then answers "Unknown method", which is why flameshot v14 gave "Unable to capture screen". It is
  the same portal that was on Arch: wlroots' screencopy. See [`flameshot.md`](../apps/flameshot.md).

The routing is explicit: Screenshot goes to `wlr`, and the rest follows the default (hyprland for
ScreenCast and GlobalShortcuts, gtk for appearance and FileChooser).

## The keyring, and the autologin interaction

gnome-keyring provides `org.freedesktop.secrets`, where apps store secrets: git through libsecret,
NetworkManager, Chrome, Spotify, Dropbox.

MIND THE AUTOLOGIN. `lightdm-autologin`'s PAM does NOT type a password, so `pam_gnome_keyring`
NEVER receives an authtok, which means the auto-unlock does NOT come from PAM. Here the "Login"
keyring has an EMPTY password (state, not declarable, rule 6): `gnome-keyring-daemon` unlocks it on
its own at startup, with no prompt, for ALL the apps.

An accepted trade: the session is already autologin and unlocked, and remote access is only
through WireGuard.

`security.pam.services.lightdm.enableGnomeKeyring` only serves an INTERACTIVE login, a rescue path
if the autologin is turned off. It is inert under autologin. `seahorse` is the "Passwords and Keys"
GUI, to manage or change the keyring's password.

## The lockscreen's PAM

`security.pam.services.hyprlock = { }` exists so hyprlock can authenticate the user's password.
WITHOUT it hyprlock does not unlock and it LOCKS YOU OUT. The package and config belong to the
user (`home/desktop/lockscreen.nix`); here it is only the PAM service, which is system level. The
empty attrset means it inherits the default login stack.
