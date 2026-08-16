# USER and SHELL: zsh as the login shell plus the v1cferr account.
# The password hash comes from sops; the SSH public keys are public, so they live here.
{ config, pkgs, ... }:

{
  # The system-wide enable is required for a login shell (/etc/shells, /etc/zshrc).
  # The interactive config and the prompt live in home/shell/.
  programs.zsh.enable = true;

  # THE USER, a declared capability. The password hash comes through sops (outside git); the SSH
  # public keys are public, so they sit here in the clear.
  users.users.v1cferr = {
    isNormalUser = true;
    description = "Victor";
    # linger: the user's systemd --user comes up at BOOT with no login, so the user services run
    # 24/7 on this always-on machine even with no graphical or SSH session open.
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
