# INPUT: the SSOT of the keyboard layout (the TTY, the greeter's xkb, Hyprland) and of the touchpad.
# No note: the defaults are the desk's, and a host with other hardware sets its own.
{ config, lib, ... }:

let
  cfg = config.my.keyboard;
in
{
  options.my.keyboard = {
    layout = lib.mkOption {
      type = lib.types.str;
      default = "br";
      description = "The xkb layout, for the greeter, Xwayland and Hyprland.";
    };
    variant = lib.mkOption {
      type = lib.types.str;
      default = "abnt2";
      description = "The xkb variant; empty for a layout's basic one.";
    };
    console = lib.mkOption {
      type = lib.types.str;
      default = "br-abnt2";
      description = "The kbd keymap of the TTY, which names layouts its own way.";
    };
  };

  # Read by Hyprland only (modules/home/desktop/input.nix); a host with no touchpad ignores it.
  options.my.touchpad = {
    naturalScroll = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Content follows the fingers, as on a phone.";
    };
    tapToClick = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "A tap is a click.";
    };
  };

  config = {
    console.keyMap = cfg.console;
    # The system's xkb covers only the greeter and Xwayland apps; Hyprland reads the same option
    # through modules/home/desktop/input.nix.
    services.xserver.xkb = {
      inherit (cfg) layout variant;
    };
  };
}
