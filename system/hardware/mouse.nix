# The Logitech MX Master 3S over Bluetooth, configured declaratively through logiops (logid).
# The boot race, the native thumb wheel and the gestures: docs/notes/mouse.md
{ pkgs, ... }:

{
  services.logiops = {
    enable = true;
    config = {
      devices = [
        {
          name = "MX Master 3S";
          dpi = 2222; # sensitivity (1000 native; the range is 200 to 8000, so tune this line to taste)

          # A smart wheel: ratchet or free spin depending on the force of the spin.
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

          # NO `thumbwheel` block on purpose: native REL_HWHEEL is what makes horizontal scroll work
          # INSIDE the apps. The divert that used to be here, and why it left: docs/notes/mouse.md

          buttons = [
            {
              cid = 195; # 0xC3 = the gesture button (under the thumb rest)
              # Gestures = MANAGING THE TAPE with the thumb. Each one synthesizes a bind that ALREADY exists
              # in keybinds.lua, so the cheatsheet (SUPER+H) still sees it.
              action = {
                type = "Gestures";
                gestures = [
                  # Left/Right: MOVE the window along the tape. Dragging does not do that (it stacks).
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
                  # Up = see everything (fit all) · Down = focus, 1 per screen. The pair of view modes.
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

  # logid has a BOOT RACE and does not re-detect on reconnect, and restarting AT the connection
  # fails with "5 tries". So udev fires a oneshot that waits for HID++ first. See the notes.
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
