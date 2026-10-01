# LIBVIRT/KVM: the daemon plus what a Windows 11 guest needs (TPM, an autostarted NAT, NOCOW images).
# Why virbr0 is NOT trusted and why OVMF is not declared: docs/notes/services/libvirt.md
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once. deadnix fails the build on an
  # entry that stops being used, so the list cannot rot into a lie (rule 16).
  inherit (pkgs) qemu_kvm;

  # libvirt's NAT bridge, named once because the firewall rule and its undo both spell it (rule 11).
  guestBridge = "virbr0";

  # The `default` network's own subnet. A literal because it is libvirt's XML that owns it here,
  # not this repo: `virsh net-dumpxml default` is the source, and the note says so.
  guestSubnet = "192.168.122.0/24";

  # Every private range, so a network added tomorrow is covered without editing this list.
  privateRanges = [
    "10.0.0.0/8"
    "172.16.0.0/12"
    "192.168.0.0/16"
  ];

  # A guest reaching for the LAN is the loudest signal it can give, so it is RECORDED and not only
  # refused. Rate limited, so a scan cannot flood the journal (grep the prefix).
  blockedPrefix = "libvirt-guest blocked: ";
in
lib.mkIf config.my.services.libvirt {
  virtualisation.libvirtd = {
    enable = true;

    # host-cpu-only, and claude-desktop's FHS ALREADY pulls this exact path, so the guest costs no
    # new closure. It drops alien-arch emulation and keeps the firmware identical (the note).
    qemu.package = qemu_kvm;

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

  # THE GUEST REACHES NO HOST SERVICE AND NO PRIVATE NETWORK. Two separate holes: `allowedTCPPorts`
  # opens a port on EVERY interface, and libvirt's FORWARD accepts ANY destination (the note).
  networking.firewall = {
    # `-I 1` like localsend.nix, so it holds wherever upstream injects its own rules. The guest's
    # OWN subnet is re-accepted LAST, which is precisely what puts it ABOVE the refusals.
    extraCommands = ''
      iptables -I nixos-fw 1 -i ${guestBridge} -j nixos-fw-refuse
      ${lib.concatMapStringsSep "\n" (
        net:
        "iptables -I FORWARD 1 -i ${guestBridge} -d ${net} -j REJECT --reject-with icmp-admin-prohibited"
      ) privateRanges}
      ${lib.concatMapStringsSep "\n" (
        net:
        "iptables -I FORWARD 1 -i ${guestBridge} -d ${net} -m limit --limit 10/min -j LOG --log-prefix \"${blockedPrefix}\""
      ) privateRanges}
      iptables -I FORWARD 1 -i ${guestBridge} -d ${guestSubnet} -j ACCEPT
    '';
    # Without this, a firewall `reload` piles up duplicates of the rules above.
    extraStopCommands = ''
      iptables -D nixos-fw -i ${guestBridge} -j nixos-fw-refuse 2>/dev/null || true
      ${lib.concatMapStringsSep "\n" (
        net:
        "iptables -D FORWARD -i ${guestBridge} -d ${net} -j REJECT --reject-with icmp-admin-prohibited 2>/dev/null || true"
      ) privateRanges}
      ${lib.concatMapStringsSep "\n" (
        net:
        "iptables -D FORWARD -i ${guestBridge} -d ${net} -m limit --limit 10/min -j LOG --log-prefix \"${blockedPrefix}\" 2>/dev/null || true"
      ) privateRanges}
      iptables -D FORWARD -i ${guestBridge} -d ${guestSubnet} -j ACCEPT 2>/dev/null || true
    '';
  };

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
