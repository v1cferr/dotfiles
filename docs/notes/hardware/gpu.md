# The GPU: an Intel Arc B580 on `xe`

`system/hardware/gpu.nix`. The machine is an i5-11400 plus an Arc B580 (Battlemage), on the open
source `xe` driver plus Mesa. A SINGLE driver, declarative, with no CUDA.

## History

This host once ran an RTX 3050 (proprietary plus CUDA) with a rescue specialisation during the
card swap. The Arc was validated (fastfetch, vainfo, `xe` loaded) and NVIDIA was REMOVED for good,
since the destination was always pure Intel. To resurrect NVIDIA, this file's git history has the
complete profile.

Ollama runs ON THIS GPU through Vulkan/Mesa ANV, so the Mesa here is a critical path for AI, not
only for games. See [`ollama.md`](../services/ollama.md).

The Battlemage requirements are already satisfied: kernel 6.18 (needs >= 6.12), Mesa 25.x (needs
>= 24.3), redistributable firmware turned on (`system/hardware/hardware.nix`).
Ref: <https://www.phoronix.com/review/intel-arc-b580-graphics-linux>

## The two boot details

- `boot.initrd.kernelModules = [ "xe" ]` loads KMS early, so the screen comes up smooth with no
  black screen.
- `reboot=pci`. On a hot `reboot` the Arc may fail to reinitialize and freeze the POST at the ASUS
  logo. `reboot=pci` forces a full reset through 0xCF9, so the firmware reinitializes the GPU
  clean, like a cold boot. If that ever stops sticking, the ladder is `bios`, `efi`, `acpi`,
  `cold`.

## Do NOT swap `extraPackages` for `pkgs.unstable.*`

TESTED AND REJECTED (06/08/2026). These `.so` files are not normal libs, they are PLUGINS loaded
impurely from `/run/opengl-driver/lib` by a loader that comes from the STABLE channel, and the
loader accepts a driver EQUAL to or OLDER than itself, never newer.

Concretely: `libva` scans `__vaDriverInit_1_<minor>` from ITS minor down to `1_0`. unstable's iHD
exports `1_24` and stable's libva 2.23 only tries up to `1_23`, so `vaInitialize failed` and all
decode/encode falls back to the CPU, in silence.

This is the general shape of the version strategy's third layer; see [`version-bumps.md`](../repo/version-bumps.md).

## Mesa is a measured exception

MESA is NOT covered by that rule, and this is measured, not a guess: `libgbm` is a separate package
(a stub) and `hardware.graphics.package` exists precisely to change Mesa's global version. Tested:
`unstable.mesa`'s ICD plus the system's loader gave an Arc B580 with `Mesa 26.1.6`, with no error.

If it is ever worth it, that is where it goes, with `package32 = pkgs.unstable.pkgsi686Linux.mesa`,
IN THAT ORDER. Today it is not worth it: nixpkgs backports the point release into the release
(mesa 26.1.5 vs 26.1.6, and the kernel and linux-firmware are IDENTICAL in both channels). For the
kernel the lever is `linuxPackages_latest`, from stable itself; see `system/core/boot.nix`.

## `iris` is broken for shader workloads

Mesa's `iris`, the OpenGL driver, calls `abort()` when the kernel refuses a batch submission, and
on this card any Minecraft shaderpack trips it within two minutes. ANV, the Vulkan driver, is fine,
so the escape is `MESA_LOADER_DRIVER_OVERRIDE=zink` per app rather than system wide. The six
coredumps and everything that was ruled out are in [`curseforge.md`](../apps/curseforge.md).
