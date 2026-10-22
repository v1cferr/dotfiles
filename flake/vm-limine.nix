# THE LIMINE DRILL: the repo's own boot modules under OVMF with Secure Boot, on DISPOSABLE keys,
# plus a fake Windows ESP for the chainload. What it proves and what it cannot: docs/notes/repo/vm-boot.md
{ inputs, pkgs }:

let
  # Only the boot modules, never the whole host: the bootloader is the thing under test.
  bootModules = map (f: ../modules/nixos/core + "/${f}") [
    "boot.nix"
    "boot-appearance.nix"
    "limine.nix"
    "boot-trust.nix"
    "alert.nix"
    "hardening.nix"
  ];

  efiLoader = "4a67b082-0a4c-41cf-b6c7-440b29bb8c4f";
  windowsGuid = "5e1ec7ed-0b00-4bad-a11e-0123456789ab";

  # A GPT disk whose ESP has that PARTUUID and the UEFI shell where bootmgfw.efi would be.
  fakeWindows =
    pkgs.runCommand "fake-windows-esp.img"
      {
        nativeBuildInputs = [
          pkgs.gptfdisk
          pkgs.dosfstools
          pkgs.mtools
        ];
      }
      ''
        truncate -s 64M $out
        sgdisk -n1:2048:-34 -t1:ef00 -u1:${windowsGuid} $out
        mkfs.vfat -F 32 --offset 2048 $out 64000
        mmd -i $out@@1M ::/EFI ::/EFI/Microsoft ::/EFI/Microsoft/Boot
        mcopy -i $out@@1M ${pkgs.edk2-uefi-shell}/shell.efi ::/EFI/Microsoft/Boot/bootmgfw.efi
      '';

  common = {
    imports = bootModules;
    my.boot.loader = "limine";
    my.boot.splash.enable = true;
    my.boot.windows.efiPartUuid = windowsGuid;
    virtualisation = {
      useBootLoader = true;
      useEFIBoot = true;
      memorySize = 2048;
      resolution = {
        x = 1920;
        y = 1080;
      };
    };
    # The LTS kernel: the drill tests the bootloader, and the image builder's VM dies on mainline.
    boot.kernelPackages = pkgs.lib.mkForce pkgs.linuxPackages;
    # QEMU's VGA in the initrd, as `xe` is on the host: without a DRM driver Plymouth falls back to text.
    boot.initrd.kernelModules = [ "bochs" ];
    # The driver adds console=ttyS0, and a serial console sends Plymouth to its text mode.
    boot.kernelParams = [ "plymouth.ignore-serial-consoles" ];
    boot.loader.timeout = 3;
    environment.systemPackages = [
      pkgs.mokutil
      pkgs.jq
    ];
  };
in
pkgs.testers.runNixOSTest {
  name = "vm-limine";
  node.specialArgs = { inherit inputs; };
  # Limine and the UEFI shell draw on the framebuffer, not the serial line the driver reads.
  enableOCR = true;

  nodes.secure = {
    imports = [ common ];
    virtualisation = {
      useSecureBoot = true;
      efi.OVMF = pkgs.OVMFFull.fd;
      efi.keepVariables = true;
    };
    # DISPOSABLE keys made inside the VM image, never the machine's (/var/lib/sbctl stays untouched).
    boot.loader.limine.secureBoot = {
      autoGenerateKeys = true;
      autoEnrollKeys.enable = true;
      autoEnrollKeys.extraArgs = [ "--yes-this-might-brick-my-machine" ];
    };
  };

  nodes.chain = {
    imports = [ common ];
    # Plain UEFI: this node proves the guid() chainload, and an unsigned shell cannot pass Secure Boot.
    boot.loader.limine.secureBoot.enable = pkgs.lib.mkForce false;
    boot.loader.timeout = pkgs.lib.mkForce 60; # the script picks the entry, read off the screen
    virtualisation.qemu.drives = [
      {
        name = "windows";
        file = "${fakeWindows}";
        driveExtraOpts = {
          format = "raw";
          snapshot = "on";
        };
      }
    ];
  };

  testScript = ''
    import json
    import time

    def screenshots(m, prefix, n, gap):
        for i in range(n):
            m.screenshot(f"{prefix}-{i:02d}")
            time.sleep(gap)

    with subtest("Secure Boot: the firmware, the loader and the enrolled config agree"):
        secure.start()
        screenshots(secure, "boot", 24, 0.5) # the menu, then the splash, for the eye
        secure.wait_for_unit("multi-user.target")

        assert "SecureBoot enabled" in secure.succeed("mokutil --sb-state")
        info = secure.succeed(
            "tail -c +5 /sys/firmware/efi/efivars/LoaderInfo-${efiLoader} | tr -d '\\0'"
        )
        print("LoaderInfo:", info)
        assert info.startswith("Limine"), info
        conf = secure.succeed("cat /boot/limine/limine.conf")
        print(conf)
        assert "guid(${windowsGuid}):/EFI/Microsoft/Boot/bootmgfw.efi" in conf
        assert "hash_mismatch_panic: yes" in conf
        assert "editor_enabled: no" in conf
        assert "#" in conf.split("module_path:")[1].splitlines()[0], "the initrd carries no hash"

    with subtest("Plymouth ran and handed over"):
        assert "splash" in secure.succeed("cat /proc/cmdline")
        secure.succeed("systemctl show -p Result --value plymouth-quit.service | grep -qx success")

    with subtest("boot-trust proves every link, and only then says verified"):
        secure.succeed("systemctl show -p Result --value boot-trust.service | grep -qx success")
        t = json.loads(secure.succeed("cat /run/boot-trust.json"))
        print("boot-trust:", t)
        assert t["secureBoot"] == "on", t
        assert t["setupMode"] == "user", t
        assert t["loader"]["signed"] == "valid", t
        assert t["integrity"] == "enrolled", t
        assert t["thisBoot"] == "verified", t

    with subtest("No failed units"):
        out = secure.succeed("systemctl list-units --state=failed --plain --no-legend --no-pager || true")
        assert not out.strip(), out

    with subtest("Shutdown splash"):
        secure.execute("systemctl poweroff >/dev/null 2>&1 &")
        # The VM may be gone before the last frame: a shot that finds no VM ends the loop.
        for i in range(6):
            try:
                secure.screenshot(f"shutdown-{i:02d}")
            except Exception:
                break
            time.sleep(0.3)
        secure.wait_for_shutdown()

    with subtest("A tampered initrd is refused, not booted"):
        secure.start()
        secure.wait_for_unit("multi-user.target")
        secure.succeed("for f in /boot/limine/kernels/*initrd*; do printf x >> $f; done; sync")
        secure.shutdown()
        secure.start()
        secure.wait_for_text("does not match")
        secure.screenshot("tampered")
        secure.crash()

    with subtest("Windows: the chainload finds the ESP by PARTUUID"):
        chain.start()
        chain.wait_for_text("Windows")
        chain.screenshot("chain-menu")
        chain.send_key("down")
        chain.send_key("ret")
        chain.wait_for_text("Shell")
        chain.screenshot("windows-chainload")
  '';
}
