# ZapFast: WhatsApp without a browser tab

`modules/home/apps/zapfast.nix`, package [`pkgs/zapfast/`](../../../pkgs/zapfast/package.nix). Upstream: <https://github.com/crmne/zapfast>.

## Why it is here

WhatsApp Web in the browser took ~1.1 GB and several seconds to open. ZapFast is native
(Rust + egui) and talks the WhatsApp protocol itself through `whatsapp-rust`, linked to the phone as
a companion device, the same slot WhatsApp Web uses. Upstream claims under a second to open and
~150 to 200 MB idle.

It has no voice or video calls. Calls stay on the phone or on WhatsApp Web in Zen.

## The ban risk, and why it was accepted

Any unofficial client breaks WhatsApp's terms, and the README says so itself: it "could get an
account suspended". What the evidence says (13/10/2026):

- Bans hit automation and suspicious signals: new accounts, VoIP numbers, emulators, messaging
  non-contacts, bulk sending. The whatsmeow bridge (mautrix-whatsapp, Beeper), the same kind of
  client, documents that plain use "shouldn't cause any bans".
- ZapFast's issue tracker had zero ban reports when this was added.
- Realistic worst case for an old personal number used by hand: the linked device is logged out,
  or a temporary suspension.

Low, not zero. Accepted for the RAM and the startup time.

## Rules that keep the risk low

- Never script or automate it. No bots, no bulk messages.
- Open WhatsApp on the phone at least once every 14 days, or linked devices get logged out.
- At the first warning from WhatsApp: unlink ZapFast (phone, Settings > Linked devices > ZapFast >
  Log out) and go back to WhatsApp Web in Zen. To uninstall, drop the import and the
  `pkgs/zapfast` package.

## Updating

`update`/`upgrade` does it: `zapfast-bump` (the package's `passthru.updateScript`, see
[docs/notes/repo/version-bumps.md](../repo/version-bumps.md)) reads the tag from a HEAD on
`/releases/latest` and the sha256 from the release's `checksums.txt`, so a no-op costs no download.

## Why the release binary and not the flake

It was the upstream flake (input `zapfast`, following `nixpkgs-unstable`) until 24/10/2026. That
flake has no binary cache, and the follows would have missed one anyway, so EVERY bump compiled
Rust: 8m44s of a 9m43s rebuild on 24/10. The `x86_64-unknown-linux-gnu` tarball needs nothing
built. It links only `libpipewire`, `libasound`, `libstdc++` and glibc 2.39, so `autoPatchelfHook`
covers it, and the Wayland, X11 and GL libraries it dlopens go on the wrapper's `LD_LIBRARY_PATH`,
the same list upstream's flake wraps. The cost is trusting upstream's CI build instead of
compiling the source.

Two things are left out of the tarball. `zapfast-portable.txt` turns on the in-app updater, which
would try to rewrite the store. The `contrib/omarchy` hook themes another distro.

**It is built WHOLE from unstable** (`final.unstable.callPackage` in `flake/overlays.nix`), for
the same reason the flake followed unstable. The session exports unstable's `alsa-lib` in
`LD_LIBRARY_PATH`, so a binary on 26.05's glibc 2.42 dies on `GLIBC_2.43 not found`. Moving only
glibc to unstable was worse: the wrapper's 26.05 Wayland/X11 libraries under glibc 2.44 aborted
with `stack smashing detected`, even on `--version`. One nixpkgs for the whole package fixes both.
