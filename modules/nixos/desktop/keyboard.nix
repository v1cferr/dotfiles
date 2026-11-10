# KEYBOARD: the SSOT of the layout (rule 11), read by the TTY, the greeter's xkb and Hyprland.
# No note: the default is the desk's ABNT2, and a host with another keyboard sets all three.
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

  config = {
    console.keyMap = cfg.console;
    # The system's xkb covers only the greeter and Xwayland apps; Hyprland reads the same option
    # through modules/home/desktop/keyboard.nix.
    services.xserver.xkb = {
      inherit (cfg) layout variant;
    };
  };
}
