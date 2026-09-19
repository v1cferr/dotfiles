# LIBVIRT/KVM: the daemon plus what a Windows 11 guest needs (TPM, an autostarted NAT, NOCOW images).
# Why virbr0 is NOT trusted and why OVMF is not declared: docs/notes/services/libvirt.md
{
  config,
  lib,
  pkgs,
  ...
}:

lib.mkIf config.my.services.libvirt {
  virtualisation.libvirtd = {
    enable = true;

    # host-cpu-only, and claude-desktop's FHS ALREADY pulls this exact path, so the guest costs no
    # new closure. It drops alien-arch emulation and keeps the firmware identical (the note).
    qemu.package = pkgs.qemu_kvm;

    # TPM 2.0 is a Windows 11 INSTALL requirement and the only item on that list Nix declares: the
    # Secure Boot UEFI already ships with qemu, and declaring OVMF now FAILS the build (the note).
    qemu.swtpm.enable = true;

    # qemu as `qemu-libvirtd` and NOT as root, which is what Debian and Fedora do: an escape out of
    # a guest running an unreviewed payload lands unprivileged. It costs the media path (the note).
    qemu.runAsRoot = false;

    # An ACPI shutdown instead of the default `suspend`, which writes the guest's WHOLE RAM into
    # the btrfs root on every host reboot, and this machine reboots a lot.
    onShutdown = "shutdown";

    # A disposable guest does not come back on its own: `autostart` stays a per-domain decision.
    onBoot = "ignore";
  };

  # The module's own polkit rule keys `org.libvirt.unix.manage` on THIS group, so without it every
  # VM action is a password prompt. `kvm` stays out: /dev/kvm is born 0666 (measured 11/08/2026).
  users.users.v1cferr.extraGroups = [ "libvirtd" ];

  systemd.tmpfiles.rules = [
    # libvirt SHIPS the `default` NAT but starts only what is symlinked here, which is all that
    # `virsh net-autostart default` does. The path is /var/lib because sysconfdir is (the note).
    "d /var/lib/libvirt/qemu/networks/autostart 0755 root root -"
    "L+ /var/lib/libvirt/qemu/networks/autostart/default.xml - - - - ../default.xml"

    # The pool NOCOW: a qcow2 over btrfs CoW plus zstd fragments as the guest writes it. `h` sets
    # the attribute on the DIRECTORY, so every image created later inherits it (same as @swap).
    "d /var/lib/libvirt/images 0711 root root -"
    "h /var/lib/libvirt/images - - - - +C"
  ];
}
