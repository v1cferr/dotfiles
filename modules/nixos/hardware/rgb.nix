# The GPU's RGB through OpenRGB: the colour is declared here and applied at every boot.
# Why the package is patched and what the card actually speaks: docs/notes/hardware/gpu-rgb.md
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (pkgs) openrgb;

  cfg = config.my.rgb;

  # The name the patched detector registers, which is also what `--device` matches on.
  device = "ASRock Intel Arc B580 Steel Legend 12GB OC";
in
{
  options.my.rgb = {
    color = lib.mkOption {
      type = lib.types.strMatching "[0-9A-Fa-f]{6}";
      default = "000000";
      example = "00FFFF";
      description = ''
        RRGGBB applied to the three zones of the GPU (the Steel Legend logo, the fans and the
        ARGB header) at boot. `000000` turns them off, which is what this machine wants by
        default: the card is one metre away from the screen and the light is noise.
      '';
    };
  };

  config = {
    # The server runs as root and owns the i2c access. That is the point of it: `/dev/i2c-*`
    # stays root-only, and the GUI started as my user reaches the card through the server
    # instead of needing privileges of its own.
    services.hardware.openrgb.enable = true;

    systemd.services.openrgb-gpu = {
      description = "Apply the declared colour to the GPU's LEDs";
      after = [ "openrgb.service" ];
      wants = [ "openrgb.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      # The wait is not decoration: the server answers before it has finished detecting, and on
      # a cold boot the card takes the longest. Asking for the device list until the GPU is in
      # it is the only honest ready signal the SDK offers.
      script = ''
        for _ in $(seq 30); do
          if ${lib.getExe openrgb} --list-devices | grep -qF ${lib.escapeShellArg device}; then
            exec ${lib.getExe openrgb} \
              --device ${lib.escapeShellArg device} \
              --mode direct \
              --color ${lib.escapeShellArg cfg.color}
          fi
          sleep 1
        done

        echo "the GPU never appeared in openrgb's device list" >&2
        exit 1
      '';
    };
  };
}
