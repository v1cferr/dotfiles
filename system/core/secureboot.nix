# SECURE BOOT: our own keys through sbctl, signing GRUB on every switch.
# The runbook, what it does NOT protect, and why -m is mandatory: docs/notes/boot.md
{ pkgs, ... }:

let
  # Signs GRUB on every switch: grub-install rewrites grubx64.efi when you least expect it.
  signGrub = pkgs.writeShellApplication {
    name = "grub-sbctl-sign";
    runtimeInputs = [ pkgs.sbctl ];
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
    '';
  };
in
{
  # The tool for the runbook above (create-keys / enroll-keys / status / verify).
  environment.systemPackages = [ pkgs.sbctl ];

  # It runs at the end of install-grub.sh, after the menu entries (grub.nix:837).
  boot.loader.grub.extraInstallCommands = "${signGrub}/bin/grub-sbctl-sign";
}
