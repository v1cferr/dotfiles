# The VPS mount

Module: [`modules/home/services/vps-mount.nix`](../../../modules/home/services/vps-mount.nix)

`~/VPS` is the KingHost VPS' whole root (`/`) over rclone SFTP with a VFS cache, so it shows up in
Dolphin (the "VPS" place) as a normal folder. It is the twin of `~/FAI-workstation`
([fai-workstation.md](fai-workstation.md)); the cache options and the reason for rclone over SSHFS
are explained there.

## As v1cferr, on purpose

The mount logs in as `v1cferr`, the same user as `ssh vps`. `/srv/imobos` and the home are
writable; whatever root owns (`/etc`, `/var/backups/imobos`, `/etc/imobos/backup.env`) is read-only
or closed. Running the remote `sftp-server` through `sudo -n` (rclone's `server_command`) would
open all of it, and a wrong drag in a file manager could then take out `/etc`, the separate `/boot`
partition or the backup secrets. Root edits stay in `ssh vps` plus `sudo`, where they are deliberate.

## Mounted at login

Unlike the workstation, the VPS is a public host, so there is no tunnel to gate it on:
`autoMount = true`. The network takes a few seconds at login, so `StartLimitIntervalSec` is cleared
and the unit retries every 10 s. The unit is `rclone-mount:.@vps.service`; its name derives from the
mount path `"/"`.

Host and user come from the `vps` block in `ssh.nix`, never a second literal, and the key is the
existing `~/.ssh/id_ed25519`, so there are zero secrets in Nix. `~/VPS` is excluded from restic: it is
somebody else's FUSE, root cannot `lstat` it, and the VPS has its own backup.

**The `key mismatch` trap.** `~/.ssh/known_hosts` holds only the VPS' ed25519 key (the one OpenSSH
picked), while Go's SSH library inside rclone offers ECDSA first and then refuses the handshake with
`knownhosts: key mismatch`, even though the host is the same. `host_key_algorithms = "ssh-ed25519"`
pins it to the key that is on file.

**A write into a root-owned directory LOOKS like it worked.** With `vfs-cache-mode = "writes"` the
write lands in the local cache first, so `touch ~/VPS/etc/x` succeeds and the file even shows up in
the listing. The upload is what fails (`Update Create failed: permission denied` in
`journalctl --user -u 'rclone-mount:.@vps'`), and rclone keeps retrying it. The file never reaches
the VPS; deleting it from `~/VPS` drops it from the cache. Measured on 16/10/2026.
