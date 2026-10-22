# BOOT TRUST: a read-only root oneshot that writes what the boot chain can PROVE to
# /run/boot-trust.json, for the NixOS Center. Every field and why: docs/notes/boot-and-storage/boot.md
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once.
  inherit (pkgs)
    coreutils
    gnugrep
    jq
    sbsigntool
    writeShellApplication
    ;

  cfg = config.my.boot;
  efiGlobal = "8be4df61-93ca-11d2-aa0d-00e098032b8c";
  efiLoader = "4a67b082-0a4c-41cf-b6c7-440b29bb8c4f"; # the Boot Loader Interface vendor GUID

  probe = writeShellApplication {
    name = "boot-trust";
    runtimeInputs = [
      coreutils
      gnugrep
      jq
      sbsigntool
    ];
    text = ''
      out=/run/boot-trust.json
      vars=/sys/firmware/efi/efivars
      configured=${cfg.loader}

      # One byte after the 4 attribute bytes; a missing variable is UNKNOWN, never "off".
      byte() { [ -r "$vars/$1" ] && od -An -tu1 -j4 -N1 "$vars/$1" | tr -d ' ' || echo ""; }
      case "$(byte SecureBoot-${efiGlobal})" in 1) sb=on ;; 0) sb=off ;; *) sb=unknown ;; esac
      case "$(byte SetupMode-${efiGlobal})" in 0) setup=user ;; 1) setup=setup ;; *) setup=unknown ;; esac

      # Only a loader that implements the Boot Loader Interface names itself; GRUB does not.
      running=unknown
      if [ -r "$vars/LoaderInfo-${efiLoader}" ]; then
        running="$(tail -c +5 "$vars/LoaderInfo-${efiLoader}" | tr -d '\0')"
      fi

      if [ "$configured" = limine ]; then
        binary=/boot/efi/limine/BOOTX64.EFI
      else
        binary="$(find /boot/EFI -maxdepth 2 -iname grubx64.efi -print -quit 2>/dev/null || true)"
      fi
      signed=unknown
      if [ -z "$binary" ] || [ ! -e "$binary" ]; then
        signed=missing
      elif [ -r /var/lib/sbctl/keys/db/db.pem ]; then
        if sbverify --cert /var/lib/sbctl/keys/db/db.pem "$binary" >/dev/null 2>&1; then
          signed=valid
        else
          signed=invalid
        fi
      fi

      # Limine enrolls the BLAKE2b of limine.conf INTO its binary; the hash must be found there.
      integrity=kernel-only # GRUB: the firmware checks the kernel, nothing checks the initrd
      if [ "$configured" = limine ]; then
        integrity=unknown
        conf=/boot/limine/limine.conf
        if [ -r "$conf" ] && [ -r "$binary" ]; then
          if grep -qaF "$(b2sum "$conf" | cut -d' ' -f1)" "$binary"; then
            integrity=enrolled
          else
            integrity=mismatch
          fi
        fi
      fi

      # THIS boot's evidence is taken once, at boot; a later run (after a switch) keeps it.
      if [ -r "$out" ]; then
        thisBoot="$(jq -r '.thisBoot // "unknown"' "$out")"
      elif [ "$sb" = on ] && [ "$setup" = user ] && [[ "$running" == Limine* ]] \
        && [ "$signed" = valid ] && [ "$integrity" = enrolled ]; then
        thisBoot=verified
      elif [ "$sb" = unknown ] || [ "$running" = unknown ]; then
        thisBoot=unknown
      else
        thisBoot=not-verified
      fi

      jq -n --arg sb "$sb" --arg setup "$setup" --arg configured "$configured" \
        --arg running "$running" --arg signed "$signed" --arg integrity "$integrity" \
        --arg thisBoot "$thisBoot" --arg at "$(date -Iseconds)" \
        '{secureBoot: $sb, setupMode: $setup, loader: {configured: $configured, running: $running,
          signed: $signed}, integrity: $integrity, thisBoot: $thisBoot, checkedAt: $at}' \
        > "$out.tmp"
      chmod 0644 "$out.tmp"
      mv "$out.tmp" "$out"

      # The installer does not fail on a failed `sbctl sign`: THIS is where that gets loud.
      if [ "$sb" = on ] && [ "$signed" = invalid ]; then
        ${lib.getExe config.my.alert} boot-trust security-high \
          "Bootloader NOT signed" "$binary fails sbverify; the firmware will refuse it at the next boot."
        exit 1
      fi
    '';
  };
in
{
  systemd.services.boot-trust = {
    description = "Record what the boot chain can prove (/run/boot-trust.json)";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = config.my.systemd.hardened // {
      Type = "oneshot";
      ExecStart = lib.getExe probe;
    };
  };

  # Re-run whenever an install rewrites the menu, so a silent signing failure surfaces at once.
  systemd.paths.boot-trust = {
    wantedBy = [ "multi-user.target" ];
    pathConfig.PathChanged = [
      "/boot/limine/limine.conf"
      "/boot/grub/grub.cfg"
    ];
  };
}
