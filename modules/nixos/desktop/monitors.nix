# MONITORS: the SSOT of the connector NAMES (rule 11), which were duplicated across 8 files.
# Why modules/nixos/ and not modules/home/, and why there is NO default: docs/notes/hardware/monitors.md
{ lib, ... }:

{
  options.my.monitors = {
    primary = lib.mkOption {
      type = lib.types.str;
      description = "The MAIN monitor's connector: origin 0x0, workspaces 1 to 4. Set by the host.";
    };
    secondary = lib.mkOption {
      type = lib.types.str;
      description = "The SECONDARY monitor's connector: on the left, workspaces 5 to 8. Set by the host.";
    };
    # The Hyprland rule of each panel. The defaults fit ANY panel, so a host only states what its
    # hardware needs (a refresh rate above the preferred one, a rotation, a place on the desk).
    primaryMode = lib.mkOption {
      type = lib.types.str;
      default = "preferred";
      example = "2560x1440@180";
      description = "The main monitor's mode; it always sits at 0x0.";
    };
    secondaryMode = lib.mkOption {
      type = lib.types.str;
      default = "preferred";
      example = "1920x1080@143.98";
      description = "The secondary monitor's mode.";
    };
    secondaryPosition = lib.mkOption {
      type = lib.types.str;
      default = "auto";
      example = "-1080x-240";
      description = "Where the secondary sits relative to the main one's 0x0, in LOGICAL pixels.";
    };
    secondaryTransform = lib.mkOption {
      type = lib.types.ints.between 0 7;
      default = 0;
      description = "The secondary's rotation, as Hyprland counts it (1 = 90 degrees).";
    };
    # Human names for the shell's labels (the NixOS Center's screenshot targets), never for matching.
    primaryName = lib.mkOption {
      type = lib.types.str;
      default = "Main";
      description = "The main monitor's short name in the UI.";
    };
    secondaryName = lib.mkOption {
      type = lib.types.str;
      default = "Side";
      description = "The secondary monitor's short name in the UI.";
    };
  };
}
