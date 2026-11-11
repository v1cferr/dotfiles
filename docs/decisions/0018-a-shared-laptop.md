# 0018. The laptop is one system with two homes, and a host picks its roles

A second NixOS host, a ThinkPad T480s shared by two people, is declared here as ONE system, and
each person keeps their own home configuration in their own repository.

- **Status**: accepted, the secrets part to review by 2027-01-31
- **Date**: 10/11/2026

## Context

Until now this repo described one desk. `modules/nixos/` was "the config common to every host",
which with a single host also meant everything that desk DOES in the house: it is reached from
outside over SSH, it routes the home LAN into the FAI VPN, it keeps the router's log, it never
suspends and it logs in by itself so Sunshine has a session to stream.

The T480s is none of that. It leaves the house, it suspends, and it is used by my brother Cesar
and by me, each with a different desktop: he starts on GNOME, I bring Hyprland. He is learning
NixOS and will shape his own dotfiles; mine already exist. So three questions needed one answer
each: who owns the machine, where each person's configuration lives, and how the shared modules
stop assuming the desk.

What was compared and REJECTED:

- **Two system configurations**, one per person: a machine has one kernel, one bootloader and one
  display manager, so two repos writing them is two owners of one artifact (rule 14).
- **His dotfiles as a flake input of this repo**: one `rebuild` would apply both homes, but every
  change of his would wait for my `update`, and a mistake in his home would fail my system build.
- **An enable option per role** (`my.roles.gateway.enable`): the reason
  [0009](0009-modules-hosts-tools-layout.md) gave for devices still holds, a host importing the
  module says the same thing with no new interface.
- **Handing the laptop the desk's age key**: every secret in `secrets/secrets.yaml` would sit on a
  machine that travels and that a second person uses.
- **LightDM for both sessions**: GNOME's screen lock is GDM's, and without GDM a GNOME session
  cannot lock.

## Decision

**One system, declared here.** `hosts/t480s/` is the machine: disk, hardware, bootloader, display
manager, both accounts and the desktops the greeter offers. A system-level change for either
person is a commit in this repo.

**Two homes, two owners.** Mine is `modules/home/`, applied by the NixOS module as on the desk.
Cesar's is standalone Home Manager from his own repository: he runs `home-manager switch` as
himself, needs no `sudo` for it, and neither home can break the other or the system build. His
account is in `wheel` since 10/11/2026: the machine is his too. What `sudo` cannot do is drift
the system, since whatever is not declared here is gone at the next rebuild.

**GDM is the greeter**, with no autologin, offering GNOME, Hyprland and an **own session**: one
entry that runs `~/.config/session/start` from the home of whoever logs in. A greeter only lists
sessions the SYSTEM declares, so without it every compositor Cesar wanted to try would be a
commit of mine; with it he picks one from his own Home Manager. A full desktop environment
still needs system services, and stays a request.

**The laptop's disk is encrypted** with LUKS under the same btrfs layout as the desk. It is the
case [0006](0006-no-disk-encryption.md) names as the default, a machine that leaves the house;
0006 itself still stands for the desk.

**A host picks its roles.** A module that describes what ONE machine does in the house is
imported by that host, exactly like a device module (rule 4), and the category `default.nix`
keeps only what every host gets. The desk's are listed in `hosts/ex-b560m-v5/roles.nix`: the
exposed SSH and its guards, the FAI gateway, the router's log, the VPNs, LightDM with autologin,
the secrets vault and the games.

**The laptop holds none of the desk's secrets.** `secrets/secrets.yaml` is not readable there.
Both password hashes are root-only files written once by the install, outside the store and
outside git.

## Consequences

- Moving the role modules changed the ORDER in which the desk's firewall rules are inserted, and
  nothing else (`nix-diff` on 10/11/2026: the same rules, the same packages and the same tmpfiles
  entries, reordered). The verdicts are the same for every real path; the one visible change is
  that a libvirt guest reaching for a FAI subnet is now rejected by the libvirt rule first.
- The laptop has no VPN, no binary cache key and no sops secret until the secrets question is
  answered. The likely answer is a second sops file with its own recipients, which is why this
  part carries a review date.
- The password files are state the repo cannot regenerate: a reinstall asks for them again.
- `modules/home/` still reaches the laptop whole, with the desk's two-monitor layout. Splitting it
  is the open item [0009](0009-modules-hosts-tools-layout.md) already left for this day.
- Secure Boot is signed for but not enforced on the laptop: Limine generates its own keys at the
  install, and enrolling them in the firmware is a manual step that has not been done.
