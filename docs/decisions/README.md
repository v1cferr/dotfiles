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
