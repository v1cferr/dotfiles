# vm-boot: does this config still boot on a machine that is not this one?

`nix build .#vm-boot`. A NixOS test that boots THIS host inside QEMU and asserts that the config
was APPLIED, not merely that it evaluated. `hosts/nixos-kingston/vm-boot.nix` is the variant it
boots.

Rule 8 requires `nixos-rebuild build` before the switch, which proves the tree EVALUATES and
BUILDS. Nothing proved it BOOTS anywhere other than on this machine, and that is the question the
whole repo exists to answer: if the hardware dies tomorrow, does the SSOT still produce a running
system? Building is not booting, the same distinction [`flake.md`](flake.md) records between
evaluating and building.

## Why it is a package and NOT a check

Anything in `checks` enters `nix flake check`, so the CI would build a whole desktop closure and
run QEMU on a free runner with ~20 GB free. That is the same reason `system.build.toplevel` stays
out of the gate, and it is why `vm-boot` is also removed from `checks.packages`, next to
`curseforge`, each with its own reason.

So this one runs HERE, on the machine that has the store warm, and it needs a weekly trigger:
a check nobody remembers to run is a check that does not exist, which is the argument the CI's own
header makes.

## The variant is not a second config

`commonModules` was hoisted out of `mkHost` for this: the test builds the SAME module list the host
builds, plus `hosts/nixos-kingston/vm-boot.nix`. One definition, two consumers, instead of a copy
that drifts (rule 14). What the variant turns off is only what needs the real hardware, a secret or
another machine:

| Override | Why |
| --- | --- |
| `disko.devices = mkForce { }` | disko generates the Kingston's fileSystems and the test VM brings its own root; keeping both waits forever for a device that does not exist |
| `/mnt/seagate-old` as tmpfs | it is a second physical disk, and the mount point still has to exist |
| every `my.services` off | they need secrets, `/srv`, a GPU or the private input. Read from the OPTION SET (`options.my.services`), never from a copy of the list, so a toggle added tomorrow is off here by construction (rule 11) |
| lightdm and autoLogin off | no GPU and no monitor. A session that cannot start would drown the failed-unit list this test exists to read |

`node.pkgsReadOnly = false` is needed because `runNixOSTest` pins the node's `pkgs` and makes the
`nixpkgs.*` options read-only, while this config sets both `nixpkgs.overlays` (in `flake.nix`) and
`nixpkgs.config.allowUnfree` (in `system/core/core.nix`). Without it the eval dies on
"nixpkgs.config is set to read-only".

## What it found on the first run, before it ever booted

**`my.services.jellyfin = false` did not evaluate.** `system/services/jellyfin.nix` declared
`users.users.jellyfin.extraGroups` OUTSIDE the toggle, so with the service off the user was
half-declared and the assertion fired: "Exactly one of isSystemUser and isNormalUser must be set".
The panel in `hosts/<host>/services.nix` was offering a switch that did not work, and nothing could
have caught it while this machine kept the service ON. The `systemd.services.jellyfin` UMask
override had the same shape and would have declared a unit with no `ExecStart`. Both moved behind
the toggle.

That is the class of bug this test exists for: a declaration that only works because another module
happens to complete it.

## The first version of the test LIED, and this is the important part

It asserted only on `systemctl list-units --state=failed` and passed green. The full log said
otherwise:

```text
sops-install-secrets: cannot read keyfile '/var/lib/sops-nix/key.txt'
Activation script snippet 'setupSecretsForUsers' failed (1)
Activation script snippet 'setupSecrets' failed (1)
```

**Activation snippets do not appear in `systemctl --failed`**, because they run inside the
activation script and not as units. A boot test that only reads failed units therefore passes while
half of the activation failed, which is worse than no test: it is a green light over a broken
system. The script now parses the journal for failed snippets and compares them against an ALLOWED
of exactly those two, each with its reason.

And the reason is the boundary of this test, not a defect: the age key lives OUTSIDE git by design
(rule 12), so a VM that never received it cannot install secrets. Proving that half is the DRILL's
job, with the key coming from the vault.

## What it proves, and what it does not

PROVES, measured on 23/08/2026: the 115 `.nix` evaluate together with the panel off; the system
reaches `multi-user.target` in 9.96s (666ms kernel, 3.675s initrd, 5.618s userspace); `sshd` comes
up; the user exists with zsh as their shell; the whole home-manager generation activates with
`Result=success`; and no unit fails.

DOES NOT PROVE: the secrets (no age key), the compositor and the GPU, the optional services (all
off), the real disk layout, or anything about hardware. The disk layout is the next stage:
`nix build .#nixosConfigurations.nixos-kingston.config.system.build.vmWithDisko` formats virtual
disks with the real disko layout, and `nixos-rebuild build-vm` is the WRONG tool for it (it hangs
waiting for the root partition on a disko layout, disko issue #668).

An oddity seen twice and NOT investigated: `nix-daemon` segfaults in `libnixstore` during the VM's
boot, with no visible effect on anything the test asserts. Written down so the next reader knows it
is known and not new.
