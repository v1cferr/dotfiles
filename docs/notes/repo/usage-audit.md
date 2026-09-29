# usage-audit: which apps show any sign of being used

`pkgs/usage-audit.nix`, run by hand with `nix run .#usage-audit`. It lists every app in
`home.packages` next to the traces of its use, with the apps that show NO trace at the top.

## Why it is a report and never a gate

`dead-config` answers "is this declared and never READ by the config", which the tree alone can
settle. "Do I still use this app" cannot be settled by the tree at all: it is a question about
runtime, and in the end a decision of mine. So nothing here fails and nothing is removed: the
output is a list to argue with, and the decision to delete is a commit, like any other.

## The signals

| Column | Source | What it catches |
| --- | --- | --- |
| Last typed | atuin's `history.db` (dated, since 09/09/2026) plus `~/.zsh_history` | a CLI I type |
| Launched | rofi's `rofi3.druncache`, a count per `.desktop` | a GUI I open from the launcher |
| Wired by `config` | the binary named in a `.lua`/`.qml`/`.json`, or `/bin/<name>` or `getExe <name>` in a `.nix` | a keybind, a bar widget, a unit, an editor setting |
| Wired by `module` | an enabled `programs.<name>` in home-manager | shell integrations, used without typing the name |
| Wired by `mime` | `xdg.mimeApps.defaultApplications` | what a double click in Dolphin opens |

**A zsh alias counts for its target**: `ls` in the history is a use of `eza`, since the alias table
is read from the evaluated config and not from the text.

**A bare name in a `.nix` is NOT a use.** The module that installs a package names it too, so that
test marked all 113 apps as wired on the first try. Only a CALL counts.

**atime was considered and rejected**: the store and btrfs mount with `noatime`/`relatime`, so a
binary's access time says nothing about the last launch.

## The first run (29/09/2026)

113 apps with something to launch (themes and data dirs are skipped). With every signal in, 22
showed no trace at all. The run went 41, 28, 22 as the alias, module, MIME and `getExe` signals
went in, and the 22 left are the list for the first review, in
[open-items](../../open-items.md). Two classes stay blind on purpose, since telling them apart
would cost more than reading the list: a tool used THROUGH another tool (`fd` by yazi, `wl-clipboard`
by a script's `runtimeInputs`) and a rescue tool that is right to sit unused.

## What it does not do yet

It reads my `~`, so it runs on the machine and never in the CI. Keeping a HISTORY of these runs, so
the pipeline can read the trend without reaching the machine, is an open question in
[ideas](../../ideas.md#app-usage-as-observability).
