# SECURE BOOT: our own keys through sbctl, signing GRUB AND every kernel on each switch.
# The runbook, and what it does NOT protect: docs/notes/boot-and-storage/boot.md
{ pkgs, ... }:

let
  # Rule 19: everything this module reaches for, named once. deadnix fails the build on an
  # entry that stops being used, so the list cannot rot into a lie (rule 16).
  inherit (pkgs)
    sbctl
    writeShellApplication
    ;

  # Signs on every switch: grub-install rewrites grubx64.efi, and each generation brings a kernel.
  signGrub = writeShellApplication {
    name = "grub-sbctl-sign";
    runtimeInputs = [ sbctl ];
    text = ''
      # No keys yet = warn and exit 0, or step 2 of the runbook would abort the activation.
      if [ ! -d /var/lib/sbctl/keys ]; then
        echo "sbctl: no keys in /var/lib/sbctl/keys, GRUB was NOT signed." >&2
        echo "       Run 'sudo sbctl create-keys' and redo the rebuild." >&2
        exit 0
      fi

      # A glob, not the literal path: bootloaderId is a nixpkgs internal. Windows' ESP is
      # another disk, so sweeping /boot cannot sign somebody else's binary.
      for efi in /boot/EFI/*/grubx64.efi /boot/EFI/BOOT/BOOTX64.EFI; do
        [ -e "$efi" ] || continue
        # Idempotent (sign.go:88). -s records it in sbctl's db so `verify` sees the file.
        sbctl sign -s "$efi"
      done

      # THE KERNEL TOO, and this is not belt and braces: on x86_64-efi GRUB does not load the
      # kernel itself, it hands the buffer to the firmware's LoadImage (loader/efi/linux.c:211),
      # which under Secure Boot demands a `db` signature and answers "cannot load image".
      # NO -s here: every generation has its own store hash and the GC deletes it, so recording
      # them would fill sbctl's database with files that stopped existing.
      for kernel in /boot/kernels/*bzImage; do
        [ -e "$kernel" ] || continue
        sbctl sign "$kernel"
      done
    '';
  };
in
{
  # The tool for the runbook above (create-keys / enroll-keys / status / verify).
  environment.systemPackages = [ sbctl ];

  # It runs at the end of install-grub.sh, after the menu entries (grub.nix:837).
  boot.loader.grub.extraInstallCommands = "${signGrub}/bin/grub-sbctl-sign";
}
