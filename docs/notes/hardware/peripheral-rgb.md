# The keyboard's and the mouse's LEDs: declared, not saved

[`modules/nixos/hardware/peripheral-rgb.nix`](../../../modules/nixos/hardware/peripheral-rgb.nix)
declares `my.rgb.peripherals` (the host sets it in `hosts/ex-b560m-v5/hardware.nix`): one look
per device, applied once at boot by `openrgb-peripherals.service`.

The obvious design was "save an OpenRGB profile and load it back". Measured on 15/10/2026, it
leaves both devices DARK. The EVision keyboard and the DeathAdder V2 keep their effect in
firmware, and OpenRGB cannot read it back: it lists them as an empty `Custom` and an empty
`Direct`, saves that, and loading it writes the emptiness. So the look is config, the same way the
GPU's colour is (`my.rgb.color`, [`gpu-rgb.md`](gpu-rgb.md)).

There is no switch. Until 21/11/2026 each device also declared a dark look, and `rgb-lights
on|off` flipped between the two: it was written for the away screen and left with it, since the
owner turns the PC off instead. Should a dark look come back: the EVision has no `Off` mode, so
its dark is `Static` with `000000`.
