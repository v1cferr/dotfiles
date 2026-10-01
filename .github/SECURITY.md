# Security policy

This repository is the declarative configuration of one personal machine. It ships no library and
no service anyone else runs, so there are no supported versions: only the `nixos` branch exists.

## Reporting a vulnerability

If you find a credential, a key or anything that should not be public in this repository or its
history, report it privately through
[GitHub's private vulnerability reporting](https://github.com/v1cferr/dotfiles/security/advisories/new)
instead of opening an issue.

## What happens next

- **Within 7 days** I acknowledge the report.
- **A leaked credential is rotated first**, before anything else, since history is never rewritten:
  the `history` ruleset forbids it, and a secret already published stays published.
- **Within 30 days** the fix lands, or I explain why it cannot, and the advisory is disclosed once
  the fix is in. You get credit in it unless you ask not to.
