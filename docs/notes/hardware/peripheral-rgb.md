# The keyboard's and the mouse's LEDs: declared, not saved

[`modules/nixos/hardware/peripheral-rgb.nix`](../../../modules/nixos/hardware/peripheral-rgb.nix)
declares `my.rgb.peripherals` (the host sets it in `hosts/ex-b560m-v5/hardware.nix`), applies the
ON look at boot, and installs `rgb-lights on|off`, which Vicinae offers as "RGB lights on" and
"RGB lights off".

The obvious design was "save an OpenRGB profile, go dark, load the profile back". Measured on
15/10/2026, it leaves both devices DARK. The EVision keyboard and the DeathAdder V2 keep their
effect in firmware, and OpenRGB cannot read it back: it lists them as an empty `Custom` and an
empty `Direct`, saves that, and loading it writes the emptiness. So the ON look is config, the
same way the GPU's colour is (`my.rgb.color`, [`gpu-rgb.md`](gpu-rgb.md)).

The EVision has no `Off` mode, so its dark is `Static` with `000000`.

The switch was written for the away screen, a black overlay with the LEDs dark that left the
shell on 21/11/2026 (the owner turns the PC off instead). The LEDs' own switch stayed.
