# The GPU's RGB: an ASRock Steel Legend B580 through OpenRGB

[`system/hardware/rgb.nix`](../../../system/hardware/rgb.nix) declares the colour,
[`flake.nix`](../../../flake.nix) carries the overlay that makes an OpenRGB capable of driving the
card, and [`pkgs/openrgb/`](../../../pkgs/openrgb/) holds the four patches it applies. All of it is
temporary by design: the section at the end says exactly when to delete it.

The card's fans are a separate story. Their LEDs are controlled here, their SPEED is not
controllable at all, and the reason is in [`gpu.md`](gpu.md).

## The LED is not where anyone assumed it was

OpenRGB's device request for this card sat open from January 2025 with the transport recorded as
"SMBus", meaning the chipset's bus. That is wrong, and it is why nothing ever happened: probing
the chipset SMBus finds nothing on this card, and the search dies there.

The controller lives on the GPU's OWN internal I2C bus, the Synopsys DesignWare adapter that the
`xe` driver registers, behind the card's AMC (Add-in card Management Controller). The whole map
falls out of sysfs with nothing loaded:

```text
/sys/bus/i2c/devices/12-0036       name = amc      (no driver bound)
  i2c-12   "Synopsys DesignWare I2C adapter"
    0000:03:00.0   8086:E20B   subsystem 1849:6020
```

Address `0x36`, and the bus number moves between boots, so anything that hardcodes `i2c-12` is
already broken.

## What it speaks, and how we know

The protocol is ASRock's, shared with the Radeon Steel Legend cards that OpenRGB already drives,
so the upstream controller needed no changes at all:

```text
10 00 <channel> <mode> R G B <speed> <brightness> <direction> 1A 00

channel   03 ARGB header   06 Steel Legend logo   07 fans
mode      01 Static through 0F Rainbow, all fifteen answer
```

Measured on the card rather than assumed, which caught a mistake in the upstream driver: it labels
byte 7 as the brightness and byte 8 as the effect speed, and it is the other way around. Stepping
byte 8 through `FF`, `40` and `00` dims the logo progressively and turns it off, while byte 7 does
nothing to brightness. The bytes it writes are correct either way, so nothing was broken, only the
comments. The correction went upstream with the measurement attached.

The card also reports its own zones, which is how the channel map above was confirmed rather than
guessed: asking `14 00 01` and reading the answer back returns bitmap `0x00C8`, that is channels
3, 6 and 7.

## The four patches, and why each one exists

| patch | whose | what it does |
| --- | --- | --- |
| `system-plugins-env.patch` | the channel's, rebased | keeps `withPlugins` working |
| `intel-gpu-i2c-bus.patch` | upstream !3612, someone else's | gives the Arc's bus a PCI identity |
| `asrock-arc-b580-steel-legend.patch` | ours | registers the card and guards the bus |
| `asrock-gpu-shutdown.patch` | ours | a missing `Shutdown()` in the destructor |

**The bus patch is the prerequisite.** OpenRGB reads the i2c adapter's parent directory to learn
which PCI device it belongs to. On AMD and Nvidia the adapter sits directly under the card, so one
truncation is enough. The Arc's adapter hangs off an intermediate `i2c_designware.768`, which
carries no PCI identity, so the bus was enumerated with vendor and device zero and could never
match a PCI detector. Walking up until a directory holding a `vendor` file appears fixes it, and
buses that were already correct exit on the first iteration.

**The guard in our patch is not paranoia.** The Arc registers THIRTEEN i2c adapters under the same
PCI device: nine gmbus, three DisplayPort AUX and the internal DesignWare bus. Once the bus patch
lands they all carry the card's PCI IDs, so a detector that only matches on IDs would write its
probe packet to address `0x36` of every one of them, the monitors' DDC buses included. The guard
restricts detection to the internal bus, and it mirrors the one the AMD path already had.

**The channel's own patch is REPLACED, not appended.** `system-plugins-env.patch` in nixpkgs no
longer applies to master, because the comment box above the `#ifdef` it anchors on changed width.
Dropping it would have been the quiet option and it would have broken `openrgb.withPlugins`
without saying so, so what is here is a rebase of it, plus the `<cstdlib>` the original leaned on
someone else's header to provide.

## Three traps in the build

**`lrelease` is not where qmake looks for it.** Master compiles the Qt translations, and qmake
bakes `qtbase/bin/lrelease` into the Makefile, but the tool lives in `qttools`. Passing
`QMAKE_LRELEASE` on the command line does not help: the mkspec overwrites it afterwards. The fix
has to happen after qmake has run, which is why the overlay does it in `postConfigure` rather than
in `qmakeFlags`.

**The udev rules changed owner, and the channel has not noticed yet.** Until 1.0 they came from
a `build-udev-rules.sh` shipped in the tree, which the channel patched to replace `/usr/bin/env chmod` with a
real path. Master DELETED that script: the binary now prints its own rules with
`--print-udev-rules`, and `make install` installs none. So the overlay clears `postPatch`, which
would otherwise fail on a file that does not exist, generates the rules from the binary in
`postInstall`, and runs the very same substitution over the OUTPUT, because the strings now live
inside the C++ instead of in a script. NixOS checks for that: a rules file that references
`/usr/bin/env` fails the build, which is how the omission announced itself.

Without the generation step the package would simply have no `lib/udev/rules.d`, and
`services.udev.packages` would install nothing, in silence. Worth remembering when the channel
does update: this is the part of the packaging that has to be rewritten, not merely rebased.

**The colour has to wait for detection.** The server answers the SDK before it has finished
finding devices, and on a cold boot the card is the slowest thing in the list. So the unit asks
for the device list until the GPU is in it rather than sleeping a magic number of seconds.

## What the udev rules hand out, and to whom

The rules the binary generates carry one line that is worth reading before accepting it:

```text
KERNEL=="i2c-[0-99]*", TAG+="uaccess"
```

`uaccess` means the user of the ACTIVE session gets the device nodes, so the GUI runs as me with
no root and no daemon in between. What it hands over is every i2c bus on the machine, the
chipset's SMBus included, which is where the RAM's SPD lives. That is the standard OpenRGB
arrangement and the price of not running a GUI as root, and it is worth saying out loud rather
than discovering later: on this machine, anything running as my user can now speak SMBus.

The server is kept anyway, since it is what applies the colour at boot, before anyone has logged
in and while `uaccess` has therefore granted nothing.

## Delete all of this when

The merge requests land and the channel catches up. Concretely: when `pkgs.openrgb` is a version
that contains the ASRock GPU controller AND the Intel bus fix, the overlay in `flake.nix`, the
whole of `pkgs/openrgb/` and this section stop having a reason to exist. What stays is
`system/hardware/rgb.nix`, which is the part that is actually about this machine.
