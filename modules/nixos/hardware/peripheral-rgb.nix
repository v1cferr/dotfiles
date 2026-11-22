# The keyboard's and the mouse's LEDs through OpenRGB: the look is declared here and applied at
# boot. Why declared and not saved from the device: docs/notes/hardware/peripheral-rgb.md
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (pkgs) openrgb;

  cfg = config.my.rgb.peripherals;

  # One `--device NAME --mode MODE [--color RRGGBB]` triple per device, so a single call sets all.
  args = lib.concatStrings (
    lib.mapAttrsToList (
      device: look:
      " --device ${lib.escapeShellArg device} --mode ${lib.escapeShellArg look.mode}"
      + lib.optionalString (look.color != null) " --color ${look.color}"
    ) cfg
  );
in
{
  options.my.rgb.peripherals = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          mode = lib.mkOption {
            type = lib.types.str;
            description = "An OpenRGB mode name, as `openrgb --list-detailed` prints it.";
          };
          color = lib.mkOption {
            type = lib.types.nullOr (lib.types.strMatching "[0-9A-Fa-f]{6}");
            default = null;
            description = "RRGGBB, for the modes that take one.";
          };
        };
      }
    );
    default = { };
    description = ''
      Peripherals by their OpenRGB device name, each with the look it wears. It is DECLARED and
      not saved from the device, because these keep their effect in firmware and OpenRGB cannot
      read it back: a saved profile restores an empty `Custom`/`Direct`, which is dark.
    '';
  };

  config = lib.mkIf (cfg != { }) {
    # The server owns hidraw/i2c as root; the boot unit reaches it over the SDK.
    services.hardware.openrgb.enable = true;

    systemd.services.openrgb-peripherals = {
      description = "Apply the declared look to the keyboard's and the mouse's LEDs";
      after = [ "openrgb.service" ];
      wants = [ "openrgb.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      # Same ready signal as openrgb-gpu: the server answers before it has finished detecting.
      script = ''
        for _ in $(seq 30); do
          devices=$(${lib.getExe openrgb} --list-devices)
          if ${
            lib.concatMapStringsSep " && " (d: "grep -qF ${lib.escapeShellArg d} <<<\"$devices\"") (
              lib.attrNames cfg
            )
          }; then
            exec ${lib.getExe openrgb}${args}
          fi
          sleep 1
        done
        echo "a declared peripheral never appeared in openrgb's device list" >&2
        exit 1
      '';
    };
  };
}
