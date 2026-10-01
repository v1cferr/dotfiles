# 0009. Modules offer, hosts compose, tools maintain

The tree is laid out by what a thing IS, so where it goes has one answer, and it was moved there without changing what the machine runs.

- **Status**: accepted
- **Date**: 30/09/2026

## Context

The repo stopped being a set of dotfiles and became the record of a small infrastructure: one
desktop, one router, and machines that will come. Its top level still said otherwise. `system/`
and `home/` were reusable capabilities with names that read like "the machine". `hosts/` meant
"NixOS configurations", so the router lived apart in `router/`. The only host was named after its
DISK (`nixos-kingston`), the part that gets swapped. `system/hardware/` imported one GPU, its RGB
controller and two mice for every host. `pkgs/` mixed software the machine runs with the checkers
that audit the repo, `ci/` held two unrelated files, `scripts/` held three files that each had a
single owner, and `flake.nix` carried seven jobs in 740 lines.

## Decision

One folder per question, and nothing is discovered: every import stays explicit.

| Question | Answer |
| --- | --- |
| Where is one machine's configuration? | `hosts/<host>/`, NixOS or not (`ex-b560m-v5`, `cudy-wr3000`) |
| Where is a reusable NixOS capability? | `modules/nixos/` |
| Where is a reusable Home Manager capability? | `modules/home/` |
| Where is software this repo packages? | `pkgs/` |
| Where is what maintains the repo itself? | `tools/` (checkers, metrics, stats, bumps, the site's builder, the CI stub) |
| Where is each flake output implemented? | `flake/`, wired one line per output in `flake.nix` |
| Where are secrets, and the docs? | `secrets/`, `docs/`, unchanged |

Three rules of placement come with it. A host is named after the BOARD it runs on, as the BIOS
guide and the Drive backup folder already were. A module describing ONE device keeps a device name
and is imported by the host that has it, never by a shared `default.nix`. A script lives next to
its single owner, so a `scripts/` folder only returns for something genuinely transversal.

What was compared and REJECTED:

- **Feature slices** (`features/foo/{nixos,home}.nix`): they dissolve the NixOS and Home Manager
  boundary, which is the one that decides WHO needs a thing (rule 4), into a folder per topic.
- **Autodiscovery** of modules: an import nobody wrote is an import nobody reviews, and
  `dead-config` could no longer tell a live module from a forgotten one.
- **flake-parts**: it would split `flake.nix` too, at the price of a second way to declare an
  output; plain `import`s with explicit arguments split it with no framework at all.
- **An enable option per device** (`my.hardware.<x>.enable`): with one host it is an abstraction
  with no second consumer. It becomes worth it the day two hosts share a device module.
- **Renaming `my.net.*` along with `net/`**: an option is an interface, so it waits for a commit
  of its own instead of riding a layout move.

## Consequences

- The move was proven to change no behavior, step by step: `nix-diff` against the previous system
  showed only the hostname and the strings that cite a path at runtime, and the hardware step
  changed only the ORDER of `environment.systemPackages`, with an identical `sw/` tree. The flake
  split kept the drvPath of the host, of every package that does not read `self` and of the
  devShell.
- The hostname became `ex-b560m-v5`, so the mDNS name and the name Moonlight shows moved with it.
  The router's DHCP reservation still says `v1cferr-nixos`, a separate decision on the device.
- `docs/history/` keeps the old paths: it is a diary, and editing it would stop it being evidence.
- Every NixOS host still gets the same `modules/home/`, including this desk's mouse OSD,
  monitor backlight and Windows games disk. A `hosts/<host>/home.nix` is the next step, the day a
  second host exists to need it.
