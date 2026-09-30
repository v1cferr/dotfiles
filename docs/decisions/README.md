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
