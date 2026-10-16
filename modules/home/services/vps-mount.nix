# ~/VPS: the KingHost VPS' root over rclone SFTP plus a VFS cache, mounted at login. As v1cferr,
# NOT root, so root's files stay read-only: docs/notes/network/vps-mount.md
{ config, ... }:

let
  vps = config.programs.ssh.settings.vps.data; # a DAG entry; SSOT: modules/home/shell/ssh.nix (rule 11)
in
{
  programs.rclone.remotes.vps = {
    config = {
      type = "sftp";
      host = vps.HostName;
      user = vps.User;
      key_file = "${config.home.homeDirectory}/.ssh/id_ed25519"; # the key `ssh vps` already uses
      known_hosts_file = "${config.home.homeDirectory}/.ssh/known_hosts"; # the VPS is already trusted
      # known_hosts holds only its ed25519 key, and Go's SSH would negotiate ECDSA: "key mismatch".
      host_key_algorithms = "ssh-ed25519";
      shell_type = "unix"; # skips the remote shell probe on every connection
    };
    mounts."/" = {
      # "/" = the whole root: what v1cferr may write is writable, the rest read-only or closed.
      enable = true;
      autoMount = true; # a public host, always reachable: no tunnel to gate it on
      mountPoint = "${config.home.homeDirectory}/VPS";
      options = {
        # The same shape as ~/FAI-workstation: reads stream through, only writes are cached.
        vfs-cache-mode = "writes";
        vfs-cache-max-age = "6h";
        vfs-cache-max-size = "2G";
        dir-cache-time = "5m"; # browsing is fast; F5 reloads
        buffer-size = "8M";
        timeout = "30s"; # a dropped link fails clean instead of freezing Dolphin
        contimeout = "15s";
      };
    };
  };

  # At login the network takes a few seconds, so systemd must not give up after 5 quick failures.
  systemd.user.services."rclone-mount:.@vps" = {
    Unit.StartLimitIntervalSec = 0;
    Service.RestartSec = 10;
  };
}
