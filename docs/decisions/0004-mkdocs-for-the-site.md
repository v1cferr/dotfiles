# 0004. The site is built with MkDocs

The first generator of the published docs, chosen as a bet with a trigger, and replaced five days later.

- **Status**: superseded by [0005](0005-fumadocs-for-the-site.md) on 23/09/2026
- **Date**: 18/09/2026

## Context

`docs/` was to become a published site, built by Nix and served from GitHub Pages, with no
backend and nothing running in production.

## Decision

MkDocs with Material for MkDocs, built from the pinned nixpkgs as a `python3.withPackages`.

## Consequences

- The whole toolchain came from the lock, and nothing landed in a profile.
- Starlight and Docusaurus were passed over: both are applications, with a Node toolchain and a
  component model this site does not need.
- **Recorded on the day as a bet**: MkDocs 1.x had shipped nothing in 24 months, and 2.0 is a
  different project under the same name. The trigger to migrate was written down, and it fired
  five days later.
