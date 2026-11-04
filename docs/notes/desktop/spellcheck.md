# Spellcheck: English and Brazilian Portuguese in every app

The conversation is in pt-BR and the code is in en-US, so every text box has to accept both at
once. There is no global switch on Linux: each app family has its own engine and reads its
languages from its own place. So there is ONE list, `my.spellcheck.languages` in
`modules/nixos/desktop/spellcheck.nix` (BCP 47 tags, rule 11), and one layer per family reads it.

## Before (measured 03/11/2026)

`spellcheck.dictionaries` in each Chromium/Electron `Preferences`:

| App | Languages |
| --- | --- |
| Obsidian | `en-US`, `pt-BR` (picked in its own settings) |
| ChatGPT (`~/.config/Codex`) | `en-US` |
| Discord | `en-US` |
| Google Chrome | `en-US` |

`/run/current-system/sw/share/hunspell` existed and was EMPTY: no system app had a dictionary.

## The layers

| Layer | Apps | Where |
| --- | --- | --- |
| hunspell dictionaries plus `DICPATH` | GTK (gspell, libspelling), Qt (Sonnet), Gecko | `modules/nixos/desktop/spellcheck.nix` |
| `spellchecker.dictionary` pref | Zen, LibreWolf | `modules/home/apps/zen.nix`, `modules/home/apps/librewolf.nix` |
| managed policy `SpellcheckLanguage` | Google Chrome (every channel) | `modules/nixos/desktop/spellcheck.nix` |

### hunspell dictionaries

`hunspellDicts.<lang>` for each language, in `environment.systemPackages`, so they land in
`/run/current-system/sw/share/hunspell`; `DICPATH` points there. Enchant (behind GTK's gspell and
libspelling) and Gecko both honor `DICPATH`. No `enchant.ordering` is declared: the default one
already falls through to hunspell/nuspell for every language we use.

Check: `enchant-lsmod-2 -list-dicts` lists `en_US` and `pt_BR`.

### Gecko (Zen, LibreWolf)

`spellchecker.dictionary` takes a comma-separated list (`en-US,pt-BR`) since Firefox 98, and the
dictionaries themselves come from `DICPATH`. Zen gets it as a `Preferences` policy (the same
`extraPolicies` block as the start page), LibreWolf as a `defaultPref` in `extraPrefs`. Both are
DEFAULTS and not locked: the context menu can still toggle a language for the session.

A page that declares its own `lang` wins over the pref: Gecko checks that page in its language
only. That is upstream behavior, not something a pref changes.

### Chrome (managed policy)

`programs.chromium` only writes policy JSON (`/etc/opt/chrome/policies/managed/extra.json`, read
by every Chrome channel, dev included) and installs no browser. `SpellcheckLanguage` LOCKS the
list, so a click in Settings cannot drop a language. Check: `chrome://policy`.

Electron apps are Chromium inside, but they do NOT read this policy.
