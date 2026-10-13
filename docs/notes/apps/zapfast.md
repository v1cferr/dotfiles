# ZapFast: WhatsApp without a browser tab

`modules/home/apps/zapfast.nix`, input `zapfast` in `flake.nix`. Upstream: <https://github.com/crmne/zapfast>.

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
  Log out) and go back to WhatsApp Web in Zen. To uninstall, drop the import and the input.

## Updating

`nix flake update zapfast`. It builds from source (no binary cache), so the first rebuild after a
bump compiles Rust for a few minutes. It follows `nixpkgs-unstable`, like zen, for the reason in
[docs/notes/repo/flake.md](../repo/flake.md).
