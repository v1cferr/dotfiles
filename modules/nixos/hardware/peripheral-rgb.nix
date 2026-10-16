# The keyboard's and the mouse's LEDs through OpenRGB: the look is declared here, applied at boot,
# and `rgb-lights on|off` is the switch the away screen flips. Why: docs/notes/desktop/away.md
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (pkgs) openrgb writeShellApplication;

  cfg = config.my.rgb.peripherals;

  # One `--device NAME --mode MODE [--color RRGGBB]` triple per device, so a single call sets all.
  args =
    state:
    lib.concatStrings (
      lib.mapAttrsToList (
        device: d:
        let
          s = d.${state};
        in
        " --device ${lib.escapeShellArg device} --mode ${lib.escapeShellArg s.mode}"
        + lib.optionalString (s.color != null) " --color ${s.color}"
      ) cfg
    );

  look = lib.types.submodule {
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
  };

  rgbLights = writeShellApplication {
    name = "rgb-lights";
    runtimeInputs = [ openrgb ];
    text = ''
      case "''${1:-}" in
        on) exec openrgb${args "on"} ;;
        off) exec openrgb${args "off"} ;;
        *) echo "usage: rgb-lights on|off" >&2; exit 2 ;;
      esac
    '';
  };
in
{
  options.my.rgb.peripherals = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          on = lib.mkOption {
            type = look;
            description = "The look while in use.";
          };
          off = lib.mkOption {
            type = look;
            description = "The look that reads as dark. Not every device has an `Off` mode.";
          };
        };
      }
    );
    default = { };
    description = ''
      Peripherals by their OpenRGB device name. The ON look is DECLARED and not saved from the
      device, because these keep their effect in firmware and OpenRGB cannot read it back: a
      saved profile restores an empty `Custom`/`Direct`, which is dark.
    '';
  };

  config = lib.mkIf (cfg != { }) {
    # The server owns hidraw/i2c as root; both the boot unit and my user reach it over the SDK.
    services.hardware.openrgb.enable = true;

    environment.systemPackages = [ rgbLights ];

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
            exec ${lib.getExe rgbLights} on
          fi
          sleep 1
        done
        echo "a declared peripheral never appeared in openrgb's device list" >&2
        exit 1
      '';
    };
  };
}
