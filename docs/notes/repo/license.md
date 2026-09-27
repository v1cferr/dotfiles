# License

[`LICENSE`](../../../LICENSE) (MIT) for the code and [`docs/LICENSE`](../../LICENSE) (CC BY 4.0)
for the documentation, chosen on 27/09/2026. The summary a reader needs is in the
[README](../../../README.md); this page is the why.

## What it had to express

"Use it as a reference, and do not copy it without credit." That is an ATTRIBUTION license and
nothing stronger. Two limits come with it, and both are the law, not the license: no license can
require credit for using something as a REFERENCE (ideas and approaches are not copyrightable),
only for copying the expression; and a license binds only what I wrote.

Until that day the repo had NO license, which is the opposite of what it looks like: with no
license, the default is "all rights reserved", so nobody could legally copy a line even WITH
credit. OpenSSF Scorecard's License check was 0 for exactly that.

## Why two licenses

**The code is MIT.** It is the most common license on dotfiles, short enough to read, and its one
condition ("the above copyright notice ... shall be included in all copies or substantial
portions") is the credit. Apache-2.0 says the same and adds a patent grant and a NOTICE file, which
is weight a machine config does not need.

**The documentation is CC BY 4.0**, because `docs/` is where most of the value of this repo is
(the measurements, the rejected alternatives), and it is prose, not software. CC BY's attribution
is also stricter than MIT's, and closer to the requirement: credit the author, link the license,
and INDICATE WHAT CHANGED. The reverse would be wrong: Creative Commons itself recommends against
its licenses for software, since they say nothing about source code or patents and are not
compatible with the software licenses.

**Passed over:** CC BY-SA and GPL-3.0. Share-alike would force whoever copies a snippet into their
own dotfiles to relicense their config, which drives away exactly the reader this repo is public
for. That is more than the requirement asked for.

## What is NOT covered

| Path | Terms | Why |
| --- | --- | --- |
| `pkgs/openrgb/*.patch` | GPL-2.0-or-later | patches to OpenRGB's GPL code; one is by another author |
| `home/desktop/quickshell/assets/razer.svg` | CC0 icon data (simple-icons) | the mark is Razer's trademark |

Everything that comes in through a flake input (the GRUB theme, the skills, the packages) is not in
the tree at all, so it keeps its own license without any note here. A new third-party file that DOES
land in the tree gets a line in this table and in the README.

The license texts are the SPDX copies, byte for byte, so GitHub and Scorecard detect them; the MIT
one only fills the year and the holder.
