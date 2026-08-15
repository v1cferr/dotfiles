# ═══════════════════════════════════════════════════════════════════════════
# SECURE BOOT: our own keys through sbctl, with GRUB signed on every switch.
#
# WHY NOT LANZABOOTE (NixOS' official, 100% declarative path): it is systemd-boot-only, and
# systemd-boot cannot list Windows from here, because each system has its own ESP on a separate
# disk (see ./boot.nix). A choice made with open eyes: the dualboot with a menu is worth more than
# the end-to-end verified chain, and the reason is that this chain is NOT COMPLETE here anyway.
#
#   WHAT THIS FILE GIVES YOU, AND WHAT IT DOES NOT. The firmware verifies GRUB (signed with this
#   machine's key) and verifies Windows' `bootmgfw.efi` (signed by Microsoft). GRUB, however,
#   loads the kernel and the initrd WITHOUT verifying anything, and that is not an accident: it is
#   the `--disable-shim-lock` in ./boot.nix, which is MANDATORY for the machine to boot (without
#   it GRUB demands the shim protocol, which does not exist here, and dies with "shim_lock
#   protocol not found", on NixOS as well as on Windows). Which means: this satisfies the firmware
#   and Windows, and it blocks a bootloader swapped from outside; it does NOT block somebody who
#   already has root and swaps the kernel. Anyone who wants the whole chain needs shim (and then a
#   kernel signed by Microsoft) or lanzaboote (and then no menu and no theme). There is no third
#   door.
#
# MICROSOFT'S CERTIFICATES: `enroll-keys -m` is MANDATORY. Without it, wiping the factory keys
# takes down along with them (a) Windows, whose bootloader is signed by MS, and (b) the Arc B580's
# option ROM, which is too. Checked on 02/08/2026 on this machine: BIOS 2803's `db` already
# carries BOTH generations of CA, the 2011 ones (Windows Production PCA / Corporation UEFI CA) and
# the 2023 ones (Windows UEFI CA 2023, Microsoft UEFI CA 2023, Option ROM UEFI CA 2023), and sbctl
# 0.18 embeds all six. That matters NOW and not in theory: the 2011 CA expired in june/2026 and
# the new Windows updates come signed by the 2023 one. Enrolling only the 2011 one would be a
# Windows that boots today and stops booting on some Patch Tuesday.
# (`--firmware-builtin` is no good here: this firmware's `dbDefault` is EMPTY.)
#
# ─── THE RUNBOOK (what is manual and why) ────────────────────────────────────
# Enrolling a key requires the firmware in Setup Mode, and Setup Mode is only entered through the
# BIOS. No part of this is automatable; what Nix automates is the signing.
#
#   0. ON WINDOWS, BEFORE ANYTHING: `manage-bde -status`. If any volume says "Protection On", run
#      `manage-bde -off C:` and WAIT for the decryption to finish. Touching Secure Boot changes
#      PCR 7, and BitLocker answers that by asking for the recovery key at boot, which nobody
#      saved, because the account is local.
#   1. `sudo sbctl create-keys`      (it creates /var/lib/sbctl/keys)
#   2. `rebuild`                     (the hook below signs GRUB)
#   3. BIOS (DEL): Secure Boot -> Key Management -> **Clear Secure Boot Keys**.
#      Save and exit (F10). That puts the firmware in Setup Mode; the boot goes on as usual.
#   4. `sudo sbctl enroll-keys -m`   (-m = with Microsoft's certificates!)
#      `sbctl status` should show Setup Mode: Disabled.
#   5. BIOS: **Secure Boot -> Enabled** (OS Type: Windows UEFI mode). Reboot.
#   6. Check: `sbctl status` (Secure Boot ✓) and `sbctl verify` (GRUB signed).
#
# IF THE MACHINE DOES NOT BOOT: turn Secure Boot off in the BIOS. There is no bricking possible
# here, since the only thing the firmware refuses is the binary, and turning SB off gives it back.
#
# `/var/lib/sbctl` IS CRITICAL STATE and it is not in restic (rule 6 sends state to the backup;
# this is state the backup does not cover). Losing that folder = the next switch does not sign
# GRUB = the machine does not boot with SB on. Recovery: SB off in the BIOS, redo steps 1 to 5.
# And it is the FIRST item to declare when impermanence lands (see docs/open-items.md), otherwise
# a reboot wipes the keys.
# ═══════════════════════════════════════════════════════════════════════════
{ pkgs, ... }:

let
  # It signs GRUB after every `nixos-rebuild switch`. It is not spare paranoia: grub-install only
  # rewrites grubx64.efi when something changes (the GRUB version, the ESP, the devices), and it
  # is EXACTLY on that switch, the one you did not foresee, that a new, unsigned binary goes to the
  # ESP. With Secure Boot on, that is a machine that does not turn on, discovered on the next
  # reboot and not on the rebuild that caused it.
  signGrub = pkgs.writeShellApplication {
    name = "grub-sbctl-sign";
    runtimeInputs = [ pkgs.sbctl ];
    text = ''
      # Before `sbctl create-keys` there is nothing to sign. It exits 0 with a WARNING instead of
      # failing: otherwise the FIRST switch to GRUB (step 2 of the runbook, when there are no keys
      # yet) would abort the whole activation. With Secure Boot still off at that point, an
      # unsigned GRUB boots normally.
      if [ ! -d /var/lib/sbctl/keys ]; then
        echo "sbctl: no keys in /var/lib/sbctl/keys, GRUB was NOT signed." >&2
        echo "       Run 'sudo sbctl create-keys' and redo the rebuild." >&2
        exit 0
      fi

      # A glob instead of the literal path: the default bootloaderId is assembled by the module as
      # distroName plus the ESP's mountpoint with '/' turned into '-' (= "NixOS-boot"), and
      # depending on that string is depending on a nixpkgs internal detail. Sweeping the ESP runs
      # no risk of signing somebody else's binary, since the Windows ESP is ANOTHER disk, never
      # /boot.
      for efi in /boot/EFI/*/grubx64.efi /boot/EFI/BOOT/BOOTX64.EFI; do
        [ -e "$efi" ] || continue
        # `sbctl sign` is IDEMPOTENT (cmd/sbctl/sign.go:88, an already signed file returns 0), so
        # running it on every switch is cheap and does not mask a real failure: any other error
        # exits != 0 and the `set -e` takes the activation down, which is what you want.
        # -s records it in sbctl's db, so `sbctl verify`/`sign-all` can see the file.
        sbctl sign -s "$efi"
      done
    '';
  };
in
{
  # The tool for the runbook above (create-keys / enroll-keys / status / verify).
  environment.systemPackages = [ pkgs.sbctl ];

  # It runs at the end of install-grub.sh, after the menu entries (grub.nix:837).
  boot.loader.grub.extraInstallCommands = "${signGrub}/bin/grub-sbctl-sign";
}
