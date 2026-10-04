# The desktop: Hyprland, autologin, portals, keyring

`modules/nixos/desktop/desktop.nix`. A Wayland compositor. LightDM (an X11 greeter) launches the Hyprland
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
at 5 min (`modules/home/desktop/lockscreen.nix`) plus remote access only through WireGuard. If you want it
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
NEVER receives an authtok, which means the auto-unlock does NOT come from PAM.

### The unlock: a TPM-sealed password (04/10/2026)

`modules/home/desktop/keyring.nix`. The "Login" keyring has a REAL password, and a copy of it is
sealed in the TPM with `systemd-creds --user` (`host+tpm2`, PCR7, the Secure Boot policy). The
three bus names the daemon owns (`org.freedesktop.secrets`, `org.gnome.keyring`,
`org.freedesktop.impl.portal.Secret`) get a service file in `$XDG_DATA_HOME/dbus-1/services`,
which wins over the system copies and points at `gnome-keyring-tpm.service`. That unit decrypts
the blob and starts the daemon with `--unlock`, so whichever app touches the keyring FIRST gets it
already open, and there is no race against an autostarted app.

- **The blob** is STATE (rule 6) at `~/.local/state/keyring/login.cred`. It only opens on this
  TPM, for this user, in this Secure Boot state.
- **Sealing**: change the password in Seahorse, then run `keyring-tpm-seal` and type the same one.
- **When PCR7 changes** (new Secure Boot keys, a dbx update), the decrypt fails and the unit starts
  the daemon LOCKED, logging a warning. The usual prompt asks once; reseal and it is silent again.
  The secrets are never lost, only the convenience.
- **What it buys**: the NVMe has no LUKS, so an empty password left every secret in plain text on
  the disk and in any copy of it. Now the file is encrypted and the key is in the TPM.
- **What it does not buy**: anyone with the running, logged-in session can read the secrets, the
  same as before. The protection is at rest.

Verified in an isolated D-Bus session first: the right password opens it, a wrong or empty one
leaves the daemon running and locked.

### Rejected

- **An empty password** (the setup until 04/10/2026). No prompt, but the keyring is stored in
  plain text on a disk without LUKS. It also drifted once: the password came back without anyone
  noticing, and VS Code started asking.
- **hyprlock unlocking it** (`security.pam.services.hyprlock.enableGnomeKeyring`). Known broken on
  NixOS: the [Discourse thread](https://discourse.nixos.org/t/automatically-unlock-gnome-keyring-with-hyprlock/54166)
  ends with people typing the password twice.
- **A greeter with a password login**: it breaks Sunshine at boot, see the autologin section.
- **LUKS with a TPM unlock** would protect the whole disk, and an empty keyring password would then
  be harmless. It needs a reinstall or a conversion, a project of its own.

`security.pam.services.lightdm.enableGnomeKeyring` only serves an INTERACTIVE login, a rescue path
if the autologin is turned off. It is inert under autologin. `seahorse` is the "Passwords and Keys"
GUI, to manage or change the keyring's password.

## The lockscreen's PAM

`security.pam.services.hyprlock = { }` exists so hyprlock can authenticate the user's password.
WITHOUT it hyprlock does not unlock and it LOCKS YOU OUT. The package and config belong to the
user (`modules/home/desktop/lockscreen.nix`); here it is only the PAM service, which is system level. The
empty attrset means it inherits the default login stack.
