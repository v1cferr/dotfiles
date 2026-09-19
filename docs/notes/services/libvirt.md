# libvirt/KVM, and the Windows 11 guest

`system/services/libvirt.nix` (the daemon) and `home/apps/virt-manager.nix` (the GUI). Two
modules because rule 4 splits them: the daemon is system level, the window is the user's app.

The reason it exists is a SANDBOX and not virtualisation as a hobby: a static review of a game
loader (19/09/2026) came back clean on the loader and BLACK BOX on the trainer payload it
deploys, because that payload only decrypts against the vendor's license server. The report's own
recommendation was to run it on something I can afford to reset. This is that something, and it
is why half the decisions below are about keeping the guest AWAY from the host rather than about
making it comfortable.

## Why it is a toggle and not just `enable = true`

`my.services.libvirt`, declared in `toggles.nix` like every other optional service. The
convention alone would justify it, but there is a mechanical reason: `hosts/nixos-kingston/vm-common.nix`
turns every `my.services` key off by reading the OPTION SET, so a new toggle is off inside the VM
boot drill BY CONSTRUCTION. An unconditional libvirtd would come up inside the drill's own QEMU,
with no nested `/dev/kvm` under it, and a failed unit on a Sunday is exactly the noise that test
exists to keep out.

## Three things the wiki tells you to do that are WRONG on 26.05

The two pages I started from ([Virt-manager](https://wiki.nixos.org/wiki/Virt-manager),
[QEMU](https://wiki.nixos.org/wiki/QEMU)) are written against an older nixpkgs. Checked each one
against the PINNED tree instead of trusting it, and three did not survive:

| What the wiki says | What 26.05 actually does |
| --- | --- |
| `qemu.ovmf.packages = [ pkgs.OVMFFull.fd ]` | REMOVED. The submodule is `internal` and there is an assertion (`libvirtd.nix:415`) that FAILS the build if any of its fields is set |
| `systemd.tmpfiles.rules = [ "L+ /var/lib/qemu/firmware ..." ]` | The module already emits that exact line itself (`libvirtd.nix:631`), so declaring it is dead config (rule 16) |
| `environment.systemPackages = [ dnsmasq ]` | Unnecessary: `dnsmasq` is already on libvirt's wrapped `binPath` (`pkgs/by-name/li/libvirt/package.nix:89`) |

So NOTHING about UEFI is declared here, and that is not an omission. Windows 11 needs Secure Boot
capable firmware, and the pinned `qemu-10.2.4` ships `50-edk2-x86_64-secure.json` in
`share/qemu/firmware`; `libvirtd-config` symlinks it into `/run/libvirt/nix-ovmf` and registers
the descriptors at `/var/lib/qemu/firmware`. Verified by listing that directory in the store path
the flake actually pins, not the one the registry resolves to.

The only Windows 11 requirement Nix does have to declare is the TPM, `qemu.swtpm.enable = true`.
Without it the installer stops at the requirements check.

## The emulator is `qemu_kvm`, and it is free here

`virtualisation.libvirtd.qemu.package` defaults to `pkgs.qemu`, which can emulate alien
architectures. Nothing here wants that: an x86_64 Windows on an x86_64 host, with KVM underneath.
The option's own documentation names the alternative, `pkgs.qemu_kvm`, host CPU only.

What made it worth changing is not the package delta (2.01 GiB against 1.45 GiB of closure) but
WHOSE path it is: `claude-desktop`'s FHS wrapper already pulls that exact
`qemu-host-cpu-only` store path, which `repo/packages.md` has recorded since 30/07/2026. So the
default was paying for a second, nearly identical emulator to sit next to one the machine already
had.

MEASURED on the whole system closure, 19/09/2026:

```text
qemu        26.89 GiB
qemu_kvm    25.95 GiB     940 MiB
```

VERIFIED BEFORE SWITCHING, because this is the part that could have quietly broken Windows 11:
`qemu_kvm` ships the SAME eight firmware descriptors, `50-edk2-x86_64-secure.json` included. A
smaller emulator that dropped the Secure Boot firmware would have traded a gigabyte for an
installer that refuses to start.

## A qemu change does NOT reach the running daemon, and that binds a VM to a dead path

This bit on the very switch that introduced `qemu_kvm`, and it will bite again on any nixpkgs bump
that moves qemu, so it is written here rather than rediscovered.

nixpkgs patches libvirt so a domain's XML records `/run/libvirt/nix-emulators/qemu-kvm`, a stable
path, and NOT the store path: the comment at `pkgs/by-name/li/libvirt/package.nix:322` says it is
"to avoid bound VMs to particular qemu derivations". `libvirtd-config` is what populates that
directory with symlinks.

The trap is that `libvirtd.service` carries `restartIfChanged = false` upstream, and
`libvirtd-config` is only pulled in through libvirtd's `requires`. So a switch that changes qemu
rebuilds both units and starts NEITHER, and the symlinks keep pointing at the previous emulator.
MEASURED right after the `qemu_kvm` switch on 19/09/2026: the active unit declared
`qemu-host-cpu-only` while `/run/libvirt/nix-emulators/qemu-kvm` still resolved to the full
`qemu-10.2.4`, timestamped from the switch BEFORE it.

Left alone, that is a silent one: a VM created in that window records the stable path, the stable
path resolves to a store path no generation references any more, and the VM stops booting at the
next `nix-collect-garbage` with an error that says nothing about garbage collection.

```text
sudo systemctl restart libvirtd-config libvirtd
```

A reboot does the same thing, which is why this mostly stays invisible on a machine that reboots
often. CHECK IT after any switch that moved qemu, and before creating a domain:

```text
readlink /run/libvirt/nix-emulators/qemu-kvm   # must match the qemu in the CURRENT generation
```

## The `libvirtd` group goes in; `kvm` still stays out

These look like the same decision and they are not, which is why both are written down.

On 11/08/2026 I nearly added `extraGroups = [ "kvm" ]` because a note told me to, and the
measurement disproved it: `/dev/kvm` is born mode 0666. I re-measured it today and it still is
(`crw-rw-rw-`), so that group would declare a permission everyone already has.

`libvirtd` is the opposite: the module installs a polkit rule (`libvirtd.nix:637`) that grants
`org.libvirt.unix.manage` to members of THAT group, and the socket is `auth_unix_rw = "polkit"`.
Without the group the daemon is reachable and every single action is a password prompt from the
polkit agent. So the group buys something real.

The test, in the shape the 11/08 lesson asked for, a TEST and not an instruction:

```text
virsh -c qemu:///system list --all   # answers with no password prompt
```

## The default network, autostarted without `virsh`

libvirt SHIPS a `default` NAT network and `libvirtd-config` copies its XML into
`/var/lib/libvirt/qemu/networks/default.xml`, but nothing starts it. Both wiki pages close that
gap with `virsh net-start default` plus `virsh net-autostart default`, typed by hand, which is
rule 3 gone.

What `net-autostart` actually does is create one symlink, so the declared form is a tmpfiles
rule:

```text
"L+ /var/lib/libvirt/qemu/networks/autostart/default.xml - - - - ../default.xml"
```

The path is under `/var/lib` and not `/etc` because nixpkgs builds libvirt with
`--sysconfdir=/var/lib` (`package.nix:354`). The ordering works out: `systemd-tmpfiles-setup`
runs in `sysinit.target`, so the symlink is created (dangling) before `libvirtd-config` copies
the target in, and `libvirtd` reads the autostart directory only after both.

## virbr0 is deliberately NOT a trusted interface

Both wiki pages say `networking.firewall.trustedInterfaces = [ "virbr0" ]`. That is not in the
module, on purpose, and this is the decision the sandbox turns on.

`trustedInterfaces` means everything arriving from the guest reaches the host, and on this
machine the host is listening: sshd on 2222, Jellyfin on 8096, qBittorrent on 8080, Ollama on
11434, the radar stacks. Handing an unreviewed Windows payload a free pass to all of it is a
strange thing to do with a machine built to isolate it.

It is not needed either, and the ordering that makes it unnecessary is MEASURED, not assumed:

```text
-P INPUT ACCEPT
-A INPUT -j LIBVIRT_INP
-A INPUT -j nixos-fw
```

libvirt's jump comes FIRST, and `LIBVIRT_INP` accepts exactly DHCP and DNS on `virbr0`. So the
guest gets an address and resolves names before `nixos-fw` ever sees the packet, and its internet
goes through `FORWARD`, which `INPUT` does not touch at all. The backend is `iptables` here
because `networking.nftables.enable` is not set, which is what the option's default keys on.

### Dropping `trustedInterfaces` was NOT enough, and I had this wrong (19/09/2026)

The first version of this page claimed that anything else the guest aimed at the host "falls
through to the NixOS firewall and is dropped". That was FALSE, and the same `iptables -S INPUT`
that confirmed the ordering is what exposed it.

`networking.firewall.allowedTCPPorts` opens a port on EVERY interface. It has no notion of where
a packet came from, so the guest sat on the same footing as the LAN:

```text
tcp 80 443 2222 8080 8096 8920 27036 27037 27040
udp 1900 5353 7359 10400 10401 27036
```

That is sshd, Caddy, qBittorrent and Jellyfin, all reachable from a VM whose whole purpose is
running something I have not read. Ollama was the one I named in the original claim that was
actually safe, since 11434 is not on that list, which is a fair measure of how much the claim was
worth.

So the interface gets an explicit refusal, the mirror of the accept idiom `localsend.nix` uses:

```text
iptables -I nixos-fw 1 -i virbr0 -j nixos-fw-refuse
```

It cannot cost the guest its network, and the ordering above is exactly why: DHCP and DNS are
already accepted in `LIBVIRT_INP` before `nixos-fw` runs, and NAT lives in `FORWARD`. What it
removes is the host's own listening services, which is the only thing the guest should never have
had.

THE GENERAL LESSON, worth more than this module: "the firewall drops it" is not a property of the
firewall being ON. `allowedTCPPorts` is a global hole, and any reasoning of the form "an untrusted
interface cannot reach X" has to name the rule that stops it, or it is a guess.

VERIFY BOTH ENDS:

```text
sudo iptables -S INPUT                 # LIBVIRT_INP must come before nixos-fw
sudo iptables -S nixos-fw | head -3    # the virbr0 refusal must be at the top
```

## qemu runs unprivileged, and what that costs

`qemu.runAsRoot = false`. NixOS defaults it to `true`, which is the outlier: Debian and Fedora
both run the emulator as an unprivileged user. With the guest running a payload nobody has read,
the difference between a QEMU escape landing as `root` and landing as `qemu-libvirtd` is the
whole point of the exercise.

THE PRICE IS THE MEDIA PATH, and it bites immediately, so it is written here rather than
discovered: `qemu-libvirtd` cannot traverse `/home/v1cferr`, which is mode 0700. An ISO sitting
in `~/Downloads` is unreadable to it no matter what libvirt chowns, because the failure is
traversal and not ownership. Install media goes in `/var/lib/libvirt/images`, which is the
default pool and where it belongs anyway.

The option's own documentation warns that flipping it later breaks existing guests' file
permissions. That is precisely why it goes in NOW, before the first domain exists.

## The images pool is NOCOW

The root is btrfs with `compress=zstd:1`, and a qcow2 is the worst possible file to put on copy
on write plus compression: the guest rewrites blocks in place, every rewrite allocates, and the
image fragments as it is used. The repo already learned this shape once, which is why `@swap`
carries neither `compress` nor `noatime`.

`systemd-tmpfiles` can set it declaratively with an `h` line, the chattr type:

```text
"h /var/lib/libvirt/images - - - - +C"
```

It is set on the DIRECTORY, which is the only form that works: `+C` on a file that already has
extents does nothing, while a new file created inside a `+C` directory inherits the attribute. So
the ordering matters and it is already right, the directory exists before any image does.

## `onShutdown` and `onBoot`, both moved off their defaults

`onShutdown = "shutdown"` instead of the default `suspend`. A suspend is a managed save, which
writes the guest's entire RAM into `/var/lib` on every host reboot, onto the same btrfs root, and
this machine reboots often. An ACPI shutdown costs the guest a boot and costs the host nothing.

`onBoot = "ignore"` instead of the default `start`, which brings back whatever was running before
the reboot. A disposable guest that resurrects itself is not disposable. Any domain that really
should come up on its own can be marked `autostart` individually, which `ignore` still honours.

## What is deliberately absent

Both are one line away and neither is here, because rule 16 charges for a declaration that is not
being used, and both happen to be holes in the isolation this VM exists to provide:

- **`virtualisation.spiceUSBRedirection.enable`**, USB passthrough. Add it the day a physical
  device has to reach the guest.
- **`qemu.vhostUserPackages = [ virtiofsd ]`**, a shared host folder. This is the one to think
  twice about: a writable host directory mounted inside the guest is the shortest path back out
  of the sandbox. Moving a file in through a one-off ISO keeps the boundary intact.

Clipboard between host and guest needs NOTHING here: it is the SPICE agent, and that is installed
inside Windows.

## What this does not cover

The guest is not declarative and is not meant to be (rule 6). The domain XML, the Windows
install and whatever the trainer writes are state, and the disposal plan is deleting the domain,
not restoring it. Nothing under `/var/lib/libvirt` is in restic's `paths`, which is `/home/v1cferr`
only, so a 64 GiB disk image is never going to land in a backup by accident.

A Unity game inside this VM runs on software rendering, with no GPU passthrough declared. That is
fine for reading a decrypted DLL out of memory and is not fine for playing anything.
