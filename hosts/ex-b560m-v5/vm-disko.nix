# The DISK LAYOUT's variant: the REAL disko config, formatted from scratch into an image and booted
# with `nix run .#disko-vm`. What it proves and what it cannot: docs/notes/boot-and-storage/disko.md
{
  lib,
  pkgs,
  ...
}:

{
  imports = [ ./vm-common.nix ];

  disko.devices.disk.kingston = {
    # 24 GiB of IMAGE instead of 953 of disk: `size = "100%"` follows it, and what is under test is
    # the LAYOUT (partitions, subvolumes, options), never the capacity.
    imageSize = "24G";

    # 1 GiB of swap instead of 16: `mkswapfile` ALLOCATES it inside the image, so the real size
    # would mean writing 16 GiB to verify a number this test does not look at.
    content.partitions.root.content.subvolumes."@swap".swap.swapfile.size = lib.mkForce "1G";
  };

  # disko builds the VM through `extendModules`, so `virtualisation.*` only exists INSIDE it and
  # has to come through here. The console on the terminal, so the drill works over SSH too.
  disko.tests.extraConfig = {
    virtualisation.graphics = false;
    virtualisation.memorySize = 4096;
    virtualisation.cores = 2;
  };

  # THE REPORT is the whole point: the drill READS a console instead of poking a shell, and what it
  # prints is what the layout actually became, not what the config says it should be.
  systemd.services.disko-layout-report = {
    description = "What the disko layout actually became, printed on the console";
    wantedBy = [ "multi-user.target" ];
    # After home-manager, so a failure of ITS is already visible below instead of being reported
    # by systemd twenty lines later with no explanation.
    after = [
      "local-fs.target"
      "home-manager-v1cferr.service"
    ];
    path = with pkgs; [
      btrfs-progs
      util-linux
      coreutils
      gnugrep
      gawk
      systemd
    ];
    serviceConfig = {
      Type = "oneshot";
      StandardOutput = "journal+console";
      StandardError = "journal+console";
    };
    script = ''
      echo "===== disko layout report ====="
      echo "--- subvolumes ---"
      btrfs subvolume list /
      echo "--- btrfs mounts ---"
      findmnt -t btrfs -o TARGET,SOURCE,OPTIONS
      echo "--- the ESP ---"
      findmnt /boot -o TARGET,SOURCE,FSTYPE,OPTIONS
      echo "--- swap ---"
      swapon --show || echo "NO ACTIVE SWAP"
      echo "--- compression in effect (the FIRST mount decides) ---"
      grep ' btrfs ' /proc/mounts | head -2
      echo "--- /home, and the user's own directory ---"
      ls -la /home || true
      # REGRESSION GUARD: a home created before @home is mounted lands here and gets masked,
      # which is the first-boot bug this VM found. Empty is the correct answer.
      echo "--- nothing should be hidden under @/home ---"
      mkdir -p /mnt/rootvol
      mount -o subvolid=5 /dev/vda2 /mnt/rootvol || true
      ls -la /mnt/rootvol/@/home || echo "nothing under @/home"
      umount /mnt/rootvol || true
      echo "--- the activation, in the initrd and in stage 2 ---"
      journalctl -b -u initrd-nixos-activation.service --no-pager --lines=20 || true
      journalctl -b -u nixos-activation.service --no-pager --lines=20 || true
      echo "--- failed units, and WHY ---"
      # --plain, or the bullet column becomes the unit name and the loop reports on nothing.
      systemctl --failed --plain --no-legend --no-pager || true
      for unit in $(systemctl --failed --plain --no-legend --no-pager | awk '{print $1}'); do
        echo "--- $unit ---"
        journalctl -u "$unit" --no-pager --lines=15 || true
      done
      echo "===== end of report ====="
    '';
  };

  # A KNOWN password, ONLY in this variant: the real one comes from sops, which has no key inside a
  # VM, and a console you cannot log into cannot answer a follow-up question.
  users.users.v1cferr = {
    hashedPasswordFile = lib.mkForce null;
    initialPassword = "drill";
  };
  users.users.root.initialPassword = "drill";
}
