# MONITORS: the SSOT of the connector NAMES (rule 11), which were duplicated across 8 files.
# Why system/ and not home/, and why there is NO default: docs/notes/monitors.md
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
  };
}
