# DESKTOP: Hyprland (Wayland) ─────────────────────────────────────────────────
# A Wayland compositor. LightDM (an X11 greeter) launches the Hyprland session; Xwayland covers
# X11 apps. Careful: in a Wayland session the keyboard and the monitors do NOT come from the
# system's xkb/xrandr, they are Hyprland config (~/.config/hypr/hyprland.conf: input.kb_layout for
# ABNT2 and the `monitor=` lines for the arrangement/primary).
# ═══════════════════════════════════════════════════════════════════════════
{ pkgs, ... }:

{
  services.xserver.enable = true; # it enables LightDM (an X11 greeter) plus Xwayland
  services.xserver.displayManager.lightdm.enable = true;
  programs.hyprland.enable = true;

  # ── Autologin ──────────────────────────────────────────────────────────────
  # The machine logs itself into Hyprland at boot. THE REASON: Sunshine (remote access) captures a
  # LIVE graphical session, so with nobody logged in there is no compositor to stream. With
  # autologin the session comes up at boot, graphical-session.target activates, and Sunshine
  # (autoStart) comes up with it, so you can connect from Moonlight without anybody touching the
  # machine. A bonus: if Hyprland crashes, LightDM logs back in on its own (resilience).
  # defaultSession is MANDATORY (a lightdm assertion) and it defines the autologin's session.
  # SECURITY: the boot lands in an UNLOCKED session. The mitigation: hypridle locks at 5min
  # (home/desktop/lockscreen.nix) and remote access is only through WireGuard. If you want it
  # locked right at boot, an exec-once of hyprlock in the autostart does it.
  services.displayManager.autoLogin = {
    enable = true;
    user = "v1cferr";
  };
  services.displayManager.defaultSession = "hyprland";
  # The system's xkb: it covers the greeter (LightDM/X11) and Xwayland apps.
  services.xserver.xkb = {
    layout = "br"; # the "br" default variant is ABNT2
    variant = "";
  };
  # Electron/Chromium apps (vscode, spotify, chrome, claude-code) run natively on Wayland instead
  # of Xwayland.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # ── The xdg-desktop-portal portals ────────────────────────────────────────
  # programs.hyprland already enables xdg.portal plus portal-hyprland (screencast).
  #   • portal-gtk: it serves org.freedesktop.appearance (color-scheme), which is how
  #     Electron/Chromium apps (vscode, chrome, spotify) go dark along with the system.
  #   • portal-wlr: it implements the Screenshot interface (portal-hyprland 1.3.12 only DECLARES
  #     it, but answers "Unknown method", so flameshot v14 gave "Unable to capture screen"). It is
  #     the same portal I had on Arch. wlroots' screencopy.
  xdg.portal.extraPortals = [
    pkgs.xdg-desktop-portal-gtk
    pkgs.xdg-desktop-portal-wlr
  ];
  # Explicit routing: Screenshot goes to wlr (hyprland does not implement it); the rest follows the
  # default (hyprland for ScreenCast/GlobalShortcuts, gtk for appearance/FileChooser).
  xdg.portal.config.common = {
    default = [
      "hyprland"
      "gtk"
    ];
    "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
  };

  # ── Keyring / Secret Service (gnome-keyring) ──────────────────────────────
  # It provides org.freedesktop.secrets, where apps store secrets (git through libsecret,
  # NetworkManager, Chrome/Spotify/Dropbox, and so on). MIND THE AUTOLOGIN: lightdm-autologin's PAM
  # does NOT type a password, so pam_gnome_keyring NEVER receives an authtok, which means the
  # auto-unlock does NOT come from PAM. Here the "Login" keyring has an EMPTY password (state, not
  # declarable, rule 6): gnome-keyring-daemon unlocks it on its own at startup, with no prompt, for
  # ALL the apps. An accepted trade-off: the session is already autologin/unlocked and remote
  # access is only through WireGuard. See the memory [[keyring-apos-restore]].
  services.gnome.gnome-keyring.enable = true;
  # It only serves an INTERACTIVE login (a rescue path, if the autologin is turned off); inert
  # under autologin.
  security.pam.services.lightdm.enableGnomeKeyring = true;
  programs.seahorse.enable = true; # the "Passwords and Keys" GUI, to manage/change the keyring's password

  # ── The lockscreen (hyprlock) ──────────────────────────────────────────────
  # PAM so hyprlock can authenticate the user's password. WITHOUT this it does not unlock and it
  # LOCKS YOU OUT. The package/config belong to the user (home/lockscreen.nix); here it is only
  # the PAM service (system level). {} = it inherits the default login stack.
  security.pam.services.hyprlock = { };
}
