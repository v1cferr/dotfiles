# DOCKER: the automatic PRUNE policy only; the ENGINE is turned on by the stacks that need it.
# The 11 GB that had no ceiling, and the 2 options that: docs/notes/services/docker-prune.md
{ config, lib, ... }:

lib.mkIf config.virtualisation.docker.enable {
  virtualisation.docker.autoPrune = {
    enable = true;

    # NOT systemd's `weekly` (Mon 00:00), which is nix-gc's slot. 04:30 queues after restic and
    # nix-optimise instead of fighting them on the same NVMe. `persistent` is already true.
    dates = "Mon 04:30";
  };
}
