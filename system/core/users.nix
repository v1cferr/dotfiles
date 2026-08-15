# ═══════════════════════════════════════════════════════════════════════════
# USER & SHELL: zsh as the login shell plus the v1cferr account (identity).
# ═══════════════════════════════════════════════════════════════════════════
{ config, pkgs, ... }:

{
  # ── The shell: zsh ──────────────────────────────────────────────────────────
  # NixOS requires the system-wide enable to use zsh as a login shell: it registers it in
  # /etc/shells, creates /etc/zshrc and turns global completion on. The interactive config
  # (history/aliases/plugins) and the prompt (starship) live in home/ (zsh.nix).
  programs.zsh.enable = true;

  # ── The user (a declared capability; password/keys = "who I am") ────────────
  # The password hash comes through sops (outside git). The SSH public keys are public, so that is
  # fine.
  users.users.v1cferr = {
    isNormalUser = true;
    description = "Victor";
    # linger: it brings v1cferr's systemd --user up at BOOT, with no need to log in, so the user
    # services (Dropbox and so on) run 24/7 on this always-on remote-access machine, even with no
    # graphical/SSH session open.
    linger = true;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    shell = pkgs.zsh; # the login shell is zsh (the interactive config is in home/zsh.nix)
    hashedPasswordFile = config.sops.secrets.v1cferr_password_hash.path;
    openssh.authorizedKeys.keys = [
      # the key that gets into the Arch today (~/.ssh/authorized_keys)
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKPvFX6AAslYtCXeUnNmSIKL4GESHvgO+irlnJ5+2ltD dev.victorferreira@gmail.com"
      # the local key on the Arch/Kingston, for the Arch -> NixOS hop
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINRHYth5yugzhdulstjLPJAqHuzXE6j/EVl7dHcWKIUI dev.victorferreira@gmail.com"
    ];
  };
  security.sudo.wheelNeedsPassword = true;
}
