# packages

Modules: [`home/packages.nix`](../../../home/packages.nix),
[`system/packages.nix`](../../../system/packages.nix)

The two mirrored central lists. Everything here is a decision that a one-line comment cannot
carry: why a package is on the unstable channel, why one was refused, or why one is NOT in the
list even though you would expect it.

The per-package rule itself (home by default, system only for root/rescue/driver/service) is in
the [README](../../../README.md#where-does-a-package-go).

## Why some packages come from `unstable.*`

| Package | Reason |
| --- | --- |
| `spotify` | see the CEF crash below; it stays on unstable only because there is no reason to go back |
| `yt-dlp` | it breaks whenever the sites change, so it has to be fresh |
| `speedtest-cli` | it follows speedtest.net's changes |
| `fastfetch` | new hardware and version detection |
| `flameshot` | v14 is the one with the portal capture path |
| `vscode` | its src is swapped for the official tarball anyway (see [version-bumps](version-bumps.md)) |

## Spotify crashes, and the flag lives in the package

The CEF zygote dies before the first ping: the browser aborts with
`GPU process isn't usable. Goodbye.` and the process falls to SIGTRAP in ~250ms, with no window
and no visible error. `--disable-gpu` and `--no-sandbox` change nothing; only `--no-zygote` works
around it.

The flag lives in the PACKAGE (`overlaySpotifyNoZygote`, in [`flake.nix`](../../../flake.nix)), not in
an `exec`, so that opening it from the menu picks up the same fix as the autostart unit. One
owner, rule 15.

**A correction worth keeping** (11/08/2026): this used to say that unstable's 1.2.92.147 "opens
clean, WITHOUT the flag" and that "the fix is the version, not a workaround in the launcher".
Wrong in both halves. 1.2.92.147 crashes just the same, measured again with the same message and
the same ~270ms, so the version was never the cause.

**Why it stayed invisible for 4 days**: the autostart unit's `SuccessExitStatus=1` (which exists
for a good reason, see [autostart.md](../desktop/autostart.md)) makes the unit die CLEAN, so nothing shows in
`systemctl --user --failed`. The symptom that did surface was "the Spotify icon disappeared from
the tray", which does not look like a crash at all.

## Claude Desktop needs the FHS variant

Not the pure one. The MCP servers need to find node and uv, and Cowork brings up a QEMU VM looking
for `/usr/share/OVMF/*.fd` and `/usr/bin/virtiofsd` at HARDCODED FHS paths, so outside the FHS it
answers `virtualization_tools_missing` and that is that.

The closure is 2.9 GiB, qemu_kvm being the biggest slice. The 30/07 measurement says that is not
where the disk fills up: the WHOLE `/nix/store` is 9% of it, while the Bottles are 319 GiB.

Cowork also requires **VT-x turned on in the BIOS** (here it is off: `VMX disabled by BIOS`) plus
the user in the `kvm` group. Without that, only Chat and Code work. The session and
`claude_desktop_config.json` are state (rule 6), and the app rewrites that JSON at runtime, so Nix
does not own it (rule 14).

## The Nix toolchain: why nixd and why nixfmt

**nixd and not nil.** Both are live Nix LSPs, but only nixd completes NixOS and home-manager
OPTIONS, because it compiles against the interpreter and EVALUATES the config instead of analyzing
text. In a repo that is 95% `services.*`/`programs.*`, that is the entire job. nil is better at
the rest (lighter, good diagnostics), so it is plan B: 1 line here plus the serverPath.

**nixfmt and not nixpkgs-fmt/alejandra.** It is the OFFICIAL formatter since RFC 166, which
created the Nix formatting team and moved the repo to the NixOS org. nixpkgs-fmt is DEPRECATED by
its own author; alejandra is good but unofficial, and diverging from nixpkgs on style is free
debt.

Mind the name: `nixfmt` IS ALREADY the RFC style (1.4.0, the same derivation as
`nixfmt-rfc-style`), while `nixfmt-classic` (0.6.0) is the old one. Asking for the classic by
mistake would reformat the whole repo in the old style.

**statix and deadnix answer different questions**, which is why both are installed: statix finds
idiomatic anti-patterns (`a = x.a;` that should be `inherit (x) a;`) and deadnix finds dead
declarations (unused lambda args, let-bindings, patterns). Here they are only available to run by
hand; what GUARANTEES them is `nix flake check`. Two statix lints are turned off with a
justification in [`statix.toml`](../../../statix.toml), because 63 of the initial 77 findings were a
single lint that contradicts the nixpkgs idiom.

## azure-cli earns its 0.95 GiB, wrangler did not earn its 2.2

Both are big CLIs from a cloud vendor, and they went opposite ways, so the comparison is the
point: **the criterion is not size, it is whether the tool does the job.**

**azure-cli stays.** 0.95 GiB marginal (the closure is 1.19, but 0.24 is already on the system).
It is the ONLY path to the Entra ID App Registration (`az ad app …`), which is the reason
everything else exists. Measured on 14/08/2026: the Azure MCP Server does NOT cover Entra. Among
its 68 tools there is no App Registration, no service principal and no Graph; its `role` is
RESOURCE RBAC, and `extension_cli_generate` only GENERATES the text of the `az` command, it never
executes. The `entra-app-registration` skill from microsoft/azure-skills confirms it inside out:
what it teaches is running `az ad app create/list/…`. As a bonus it simplifies the MCP login, since
with `az` on the PATH azmcp's chain picks up `AzureCliCredential` and the device code stops being
necessary.

**wrangler went out**, tested and removed on 07/08/2026, the same day it went in. It costs 2.2 GiB
of closure (FOUR copies of nodejs-24: slim, -npm, -corepack and the full one) and has NO DNS or
zone command, since the whole help is Workers/Pages/KV/R2/AI. The DNS work here is done by the
`cloudflare-api` MCP ([`.mcp.json`](../../../.mcp.json)).

## What is NOT in the list, and why

- **curseforge** and **claude-code** each own their package, because they have a config of their
  own (the login scheme handler, and the separate claude-fai/claude-pessoal accounts). An app with
  declarative config keeps package and config together.
- **Java**, for CurseForge. It is dead config: see [curseforge.md](../apps/curseforge.md).
- **wrangler**, above.

## The system list is rescue and diagnosis

`restic` is there for a reason worth stating: the `services.restic` module only generates wrappers
PER REPO (`restic-home-gdrive`), so a repo with no service, like the Arch archive, was unreachable
without a `nix shell`. A backup that requires gymnastics to read is half a backup.

`nix-tree` answers a different question from `gdu`/`filelight`: those say which FOLDER weighs the
most, this one says which PACKAGE does, and what each dependency drags in. It is how we measured
that xembedsniproxy cost 429 MiB of qtwebengine.

`wayland-utils` came in on 08/08/2026 because the question "does Hyprland still serve
wlr-gamma-control?" could not be answered without guessing, and a guess becomes a wrong comment in
the repo.

The GPU benchmarks (vulkan-tools, mesa-demos, glmark2, vkmark, unigine, clpeak) were removed after
validating the Arc: they were one-offs. Only the day-to-day monitors stayed.

## A module names its packages once, at the top (rule 19)

Adopted on 29/08/2026, across 35 modules. The `let` of a module opens with an `inherit (pkgs) ...;`
listing what that module reaches for, and the body uses the bare name.

**The idea comes from nixpkgs, where it already exists.** A derivation's file header
(`{ lib, stdenv, curl, jq }:`) IS its dependency list, filled in by `callPackage`. That does not
transfer to a NixOS module, because a module's arguments are fixed by the module system: only
`config`, `options`, `lib`, `pkgs` and whatever `specialArgs` provides ever arrive there, and
`{ pkgs, curl, ... }:` fails at eval. Forcing it through `_module.args = pkgs;` would dump the whole
of nixpkgs into every module's scope and risk infinite recursion, since module arguments have to
resolve before imports do. So the `let` is where the list goes, and it is the closest legitimate
form.

**What it actually buys**, beyond reading better:

- **deadnix checks it.** An inherited name that stops being used is an unused binding, which fails
  `nix flake check` and the pre-commit hook. Rule 16 usually depends on somebody remembering to
  audit; here the linter does it.
- **It kills the mixed-scope list.** `runtimeInputs = with pkgs; [ systemd coreutils streamActive ]`
  in [`sunshine.nix`](../../../system/services/sunshine.nix) and
  `home.packages = with pkgs; [ minimizeOthers wl-clipboard ... ]` in
  [`hypr.nix`](../../../home/desktop/hypr.nix) both mixed real packages with shell applications built
  a few lines above, resolved by `with` losing to a `let` binding. Nothing on the page said which
  name was which. This is the case [nix.dev](https://nix.dev/guides/best-practices.html) has in mind
  when it says not to use `with`: it defeats static analysis and hides where a name comes from.
- **One place to swap a channel** for that module, instead of a grep through its shell strings.

**What deliberately does NOT go in the block.** The comment above it claims the list is the module's
packages, so anything else in there would be a lie:

- **Platform queries.** `pkgs.stdenv.hostPlatform.system` keeps its prefix (hypr, quickshell,
  flameshot, dropbox, razer-dpi). It is not something the module installs.
- **Namespaces.** `kdePackages` and friends are not packages, so what gets named is the ATTRIBUTE
  the module uses: `inherit (pkgs.kdePackages) kconfig;`, not the whole set.
- **The unstable channel**, which is the one exception that stays a namespace: it is inherited as
  `unstable` so every use site still reads `unstable.spotify`. The table above is kept honest by
  grepping for `unstable.` across the tree, and a package that stops spelling out its channel
  vanishes from that grep while still being on it.

**Where it does not apply.** A flat install list (`home.packages`, `environment.systemPackages`,
`fonts.packages`, `hardware.graphics.extraPackages`) keeps `with pkgs;`: every name in it comes from
the same place, there is nothing to disambiguate, and the `with` is the nixpkgs idiom for exactly
that shape. Five modules were left untouched for want of a payoff, all of them with no `let` block
and one or two single-use references: `system/hardware/mouse.nix`, `system/hardware/razer.nix`,
`hosts/nixos-kingston/vm-disko.nix`, `home/shell/git.nix` and `home/shell/cli.nix`.

**How the sweep was verified.** The change is textual, so the proof is that nothing moved: the
system's `drvPath` was read before the first edit and after every commit, and it stayed
`5hakbijzd1nq2fxh6mxf3vp3rfvglgds` throughout. Since home-manager enters as a NixOS module here, that
one hash covers both trees. It is a real check and not a formality: every service toggle is on for
this host, so all the touched modules do evaluate, and a name attributed to the wrong scope fails
loudly (`undefined variable`, or a missing attribute in the `inherit`) instead of silently building
something else.
