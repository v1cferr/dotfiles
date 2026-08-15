# The Logitech MX Master 3S mouse: a declarative configuration through logiops (the logid
# daemon). logid runs as a systemd service (root, so it reaches hidraw) and applies the config on
# hotplug. It is connected over Bluetooth (logiops 0.3.x already speaks HID++ over BT); if one
# day it does not get detected over BT, plugging the Bolt receiver (it comes in the box) solves
# it, with no change to this file.
{ pkgs, ... }:

{
  services.logiops = {
    enable = true;
    config = {
      devices = [
        {
          name = "MX Master 3S";
          dpi = 2222; # sensitivity (1000 native; the range is 200 to 8000, so tune this line to taste)

          # A smart wheel: it switches between ratchet and free spin based on the spin's force.
          smartshift = {
            on = true;
            threshold = 15; # the force to release the ratchet (lower means it releases more easily)
          };

          # High resolution scrolling (smooth, pixel by pixel).
          hiresscroll = {
            hires = true;
            invert = false;
            target = false;
          };

          # NO `thumbwheel` block on purpose: the thumb wheel stays NATIVE (REL_HWHEEL), which is
          # what makes horizontal scrolling work INSIDE the apps (VS Code, a wide table in the
          # browser, Dolphin). What scrolls the Hyprland tape is SUPER plus the wheel, bound on
          # `mouse_left`/`mouse_right` (home/desktop/hypr/lua/keybinds.lua).
          # There used to be a `thumbwheel.divert = true` here synthesizing SUPER+CTRL+,/. The
          # reason was escaping the 300ms ceiling of `binds:scroll_event_delay`, which throttles a
          # wheel bind to ~3 firings/s. It became unnecessary when the tape started moving COLUMN
          # by column (with column_width=1.0, 1 column = 1 screen): 3 screens/s is plenty, and the
          # cost of the divert (killing the apps' horizontal scroll) did not pay off.
          # If the divert is ever needed back: `interval` is ignored on the thumbwheel, since
          # logiops fires on every increment (PixlOne/logiops#310, open).

          buttons = [
            {
              cid = 195; # 0xC3 = the gesture button (under the thumb rest)
              # Gestures = MANAGING THE TAPE with the thumb, ever since scrolling became global
              # and a workspace stopped being where you stock windows. Each gesture synthesizes a
              # bind that ALREADY EXISTS in keybinds.lua, so no new action just for the mouse,
              # otherwise the cheatsheet (SUPER+H, generated from keybinds.lua) would not see it.
              # Switching workspaces stays on SUPER+1..8, SUPER+TAB and SUPER plus the vertical
              # wheel.
              action = {
                type = "Gestures";
                gestures = [
                  # Left/Right: MOVE the window along the tape (SUPER+SHIFT+,/. = swapcol l/r).
                  # It is the "put it beside with the mouse": dragging does not do that (it
                  # stacks, hardcoded).
                  {
                    direction = "Left";
                    mode = "OnRelease";
                    action = {
                      type = "Keypress";
                      keys = [
                        "KEY_LEFTMETA"
                        "KEY_LEFTSHIFT"
                        "KEY_COMMA"
                      ];
                    };
                  }
                  {
                    direction = "Right";
                    mode = "OnRelease";
                    action = {
                      type = "Keypress";
                      keys = [
                        "KEY_LEFTMETA"
                        "KEY_LEFTSHIFT"
                        "KEY_DOT"
                      ];
                    };
                  }
                  # Up = SEE EVERYTHING (SUPER+CTRL+G = fit all) · Down = focus, 1 per screen
                  # (SUPER+CTRL+. = colresize all 1.0). The pair of view modes, on the thumb.
                  {
                    direction = "Up";
                    mode = "OnRelease";
                    action = {
                      type = "Keypress";
                      keys = [
                        "KEY_LEFTMETA"
                        "KEY_LEFTCTRL"
                        "KEY_G"
                      ];
                    };
                  }
                  {
                    direction = "Down";
                    mode = "OnRelease";
                    action = {
                      type = "Keypress";
                      keys = [
                        "KEY_LEFTMETA"
                        "KEY_LEFTCTRL"
                        "KEY_DOT"
                      ];
                    };
                  }
                  # A click with no movement: the app launcher (SUPER+Q).
                  {
                    direction = "None";
                    mode = "OnRelease";
                    action = {
                      type = "Keypress";
                      keys = [
                        "KEY_LEFTMETA"
                        "KEY_Q"
                      ];
                    };
                  }
                ];
              };
            }
          ];
        }
      ];
    };
  };

  # logid has a BOOT RACE plus it does not re-detect on reconnect: if the mouse connects AFTER
  # logid comes up (BT pairs with a delay at boot, or it reconnects after sleeping), the DPI stays
  # at the default (1000) instead of the configured one. BUT restarting logid at the INSTANT of
  # the connection fails ("5 tries": the BT HID++ has not answered yet). So udev, when the MX
  # Master (046D:B034) connects, fires a oneshot that WAITS for HID++ to wake up and ONLY THEN
  # restarts logid.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="hidraw", KERNELS=="*046D:B034*", TAG+="systemd", ENV{SYSTEMD_WANTS}+="logid-reapply.service"
  '';
  systemd.services.logid-reapply = {
    description = "Reapplies the logid config when the MX Master (BT) connects and becomes ready";
    serviceConfig = {
      Type = "oneshot";
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 5"; # wait for the BT HID++ to wake up
      ExecStart = "${pkgs.systemd}/bin/systemctl try-restart logid.service";
    };
  };
}
