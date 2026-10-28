# Decisions

A decision is a CHOICE made on a date, between options that were compared: which theme, which
generator, which file the agent reads. It is not a [rule](../rules.md): a rule is an invariant
that must stay true of every commit, and a decision is allowed to be replaced. When one is, its
record is not edited into the new answer, it gets the status `superseded` and a pointer to the
record that replaced it, so the reasoning of the day survives.

Each record follows the same short shape, after [Michael Nygard's ADR](https://adr.github.io/):
**Status** and **Date**, the **Context** that forced a choice, the **Decision**, and its
**Consequences**, the ones that cost something included.

| # | Decision | Status |
| --- | --- | --- |
| [0001](0001-own-nix-palette.md) | The theme is a Nix palette of my own | accepted |
| [0002](0002-ui-font-in-system.md) | The UI font is a system option, apart from the colors | accepted |
| [0003](0003-agent-contract-in-managed-layer.md) | The agent contract lives in Claude Code's managed layer | accepted |
| [0004](0004-mkdocs-for-the-site.md) | The site is built with MkDocs | superseded by 0005 |
| [0005](0005-fumadocs-for-the-site.md) | The site is built with Fumadocs | accepted |
| [0006](0006-no-disk-encryption.md) | The disks are not encrypted | accepted, review by 2027-09-30 |
| [0007](0007-grub-over-lanzaboote.md) | GRUB stays, over lanzaboote | accepted |
| [0008](0008-no-offsite-backup-yet.md) | No offsite backup, for now | offsite: accepted risk, review by 2026-12-31; destination superseded by 0011 |
| [0009](0009-modules-hosts-tools-layout.md) | Modules offer, hosts compose, tools maintain | accepted |
| [0010](0010-visual-layer-without-component-library.md) | The site's visual layer adds no component library | accepted |
| [0011](0011-local-disk-backup.md) | The backup goes to a local disk first | accepted |
| [0012](0012-stylix-applies-the-palette.md) | Stylix applies the palette; the palette keeps the hexes | accepted, refines 0001 |
| [0013](0013-graph-view-with-one-dependency.md) | The site's graph view takes one dependency | accepted, refines 0010 |
| [0014](0014-source-previews-from-a-build-snapshot.md) | The site previews source from a snapshot built beside it | accepted, refines 0005 and 0010 |
| [0015](0015-limine-over-grub.md) | Limine replaces GRUB, so the initrd is verified too | proposed, would supersede 0007 |
| [0016](0016-bitwarden-is-the-secrets-source.md) | Bitwarden is the single source of secrets, home included | accepted |
