# The glance band's HEIGHT: its share of the standing screen, bar included, read by Theme.qml through
# a generated JSON like the palette. The 35/65 split and the 40% ceiling: docs/notes/desktop/dash.md
{ config, lib, ... }:

{
  options.my.dash.share = lib.mkOption {
    # The type IS the ceiling: above 40% the band takes the work area it exists to protect.
    type = lib.types.numbers.between 0.25 0.4;
    default = 0.35;
    example = 0.3;
    description = "The share of a standing screen's height the glance band reserves, the bar included: 0.35 by default, 0.30 for the compact profile, never above 0.40.";
  };

  config.home.file.".config/theme/dash.json".text = builtins.toJSON {
    share = config.my.dash.share;
  };
}
