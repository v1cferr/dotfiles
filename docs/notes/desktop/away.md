# The away screen: everything dark while the machine keeps working

The goal: leave an agent working for an hour and have the desk look like the PC is off, without
suspending anything. The screens go black, the keyboard and the mouse go dark, and one key brings
it all back.

## The LEDs are declared, not saved

[`modules/nixos/hardware/peripheral-rgb.nix`](../../../modules/nixos/hardware/peripheral-rgb.nix)
declares `my.rgb.peripherals` (the host sets it in `hosts/ex-b560m-v5/hardware.nix`), applies the
ON look at boot, and installs `rgb-lights on|off`.

The obvious design was "save an OpenRGB profile, go dark, load the profile back". Measured on
15/10/2026, it leaves both devices DARK. The EVision keyboard and the DeathAdder V2 keep their
effect in firmware, and OpenRGB cannot read it back: it lists them as an empty `Custom` and an
empty `Direct`, saves that, and loading it writes the emptiness. So the ON look is config, the
same way the GPU's colour is (`my.rgb.color`, [`gpu-rgb.md`](../hardware/gpu-rgb.md)).

The EVision has no `Off` mode, so its dark is `Static` with `000000`.

## The monitors are NOT turned off

Two ways to really cut the panels were ruled out:

- **DDC/CI `0xD6` (power mode)**: both panels advertise it, and `setvcp D6 4` on the LG UltraGear
  dropped the DisplayPort link (`card0-DP-2` went `disconnected`, Hyprland lost the monitor), and
  the panel stopped answering on its i2c bus, so `D6 1` never arrived. Not even
  `echo detect > /sys/class/drm/card0-DP-2/status` brought it back: only its power button did.
  Never again.
- **DPMS**: toggling it under an active Sunshine capture reset the GPU engine on `xe`
  ([`sunshine.md`](../network/sunshine.md)).

So the screens stay on and show black, which is what the user asked for anyway.

## Black is a Quickshell overlay that holds the keyboard

[`Away.qml`](../../../modules/home/desktop/quickshell/Away.qml) keeps the state and the IPC
(`qs ipc call away on|off|toggle`), and
[`away/AwayScreen.qml`](../../../modules/home/desktop/quickshell/away/AwayScreen.qml) draws one
black layer per monitor on the `overlay` layer, over the bar. Entering also turns do not disturb
on (a toast would light the screen up) and runs `rgb-lights off`; leaving restores the previous
DND and runs `rgb-lights on`.

Three details carry the design:

- **Exclusive keyboard focus.** Every key lands on the overlay and is dropped, so a cat on the
  keyboard types nothing into the agent's terminal. Only Enter is handled, and it leaves. The
  mouse does nothing, and the cursor is blanked.
- **An idle inhibitor.** hypridle's 5-min lock would otherwise draw hyprlock over the black and
  light the room. The overlay holds a Wayland idle inhibitor while it is up, which hypridle
  honours (its `ignore_dbus_inhibit` only covers D-Bus). The idle clock starts over on Enter, so
  walking away again still locks.
- **No lock of its own.** Enter alone brings the desktop back, by choice. If the room is not
  trusted, lock first (SUPER+L) and then go away.

It is reached from the moon pill next to the tray (it only turns the screen on, since the overlay
covers it) and from "Away screen" in Vicinae, which waits half a second so the Enter that launched
it is released before the overlay starts listening.

A Quickshell restart while away drops the overlay but not the LEDs: `rgb-lights on` fixes them.
