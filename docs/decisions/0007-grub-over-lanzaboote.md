# 0007. GRUB stays, over lanzaboote

Dualboot keeps GRUB, its menu and its theme, and Secure Boot keeps covering the bootloader only.

- **Status**: accepted
- **Date**: 30/09/2026, reaffirming the move to GRUB of August 2026

## Context

Lanzaboote is the Secure Boot path the NixOS community recommends, and the only one that also
verifies the kernel and initrd; GRUB is not recommended for Secure Boot on NixOS. GRUB was chosen
in August 2026 on the premise that systemd-boot cannot list a Windows that lives on another disk.
That premise is outdated: `boot.loader.systemd-boot.windows.<name>.efiDeviceHandle` boots Windows
from another ESP through the EDK2 UEFI shell, which reopens lanzaboote as an option.

## Decision

GRUB stays. The menu and the theme are worth more, on this machine, than a verified kernel.

## Consequences

- The chain stays as [boot](../notes/boot-and-storage/boot.md) describes it: the firmware verifies
  GRUB and Windows' loader, and GRUB loads the kernel without verifying it. It stops a bootloader
  swapped from outside, not somebody who already has root.
- Moving to lanzaboote later would need an untested piece first: the EDK2 shell that reaches
  Windows would have to be signed and accepted under Secure Boot too. That is the experiment to
  run in a VM before touching the real boot.
