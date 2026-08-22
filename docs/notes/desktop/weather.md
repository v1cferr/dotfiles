# The weather: one source for the bar and the lock screen

`home/desktop/weather.nix` holds the SSOT (rule 11): the coordinates and the WMO code to pt-BR
table. The two surfaces that draw weather read it, `home/desktop/quickshell/bar/Bar.qml` and the
lock screen's fetch in `home/desktop/lockscreen.nix`.

## Why the SSOT exists: they disagreed on screen

Until 22/08/2026 there were TWO sources, each with its own coordinates:

| Surface | Source | Coordinates |
| --- | --- | --- |
| the bar | Open-Meteo (JSON, WMO codes) | -21.9977, -47.8827 |
| the lock screen | wttr.in (`?format=%C,+%t`) | -22.0087, -47.8909 |

MEASURED on 22/08/2026 at 10:45, the same minute: the bar said **22°C** and the lock said
**18°C**. Two surfaces of the same desktop, 4 degrees apart, and both of them "working". That is
the same class of failure as the pretty-and-false latency the VPN probe exists to avoid, except
here you did not even need a graph to catch it: you locked the screen and the number changed.

Open-Meteo won, and wttr.in is gone:

1. **It is the one that carries CODES.** wttr.in returns PROSE (`Sunny`, `Ensolarado`), and prose
   is not data: the only way to get an icon out of it is to regex it, which is the bug below.
2. **The pt-BR came from `Accept-Language: pt`**, so the vocabulary on the lock screen was
   whatever wttr.in's own translation table happened to say, changing under us with no version
   and no way to review it. Now the words are OURS, in a Nix attrset that shows up in a diff.
3. It also gives the 7-day forecast the bar's popover already draws, in the same request.

## The icon comes from the CODE, and that is not cosmetic

`weatherIcon()` used to take the LABEL and match it with regexes (`/clear|sunny/`, `/cloud/`,
`/rain|drizzle|shower/`), and the map that produced the label carried a comment saying the strings
were written to match those regexes.

That coupling is a TRAP, and translating the labels is exactly what triggers it: `Nublado` matches
no regex, so every icon would have silently become the default cloud. Nothing would log, nothing
would crash, and the bar would just be wrong about the sky, forever. Rule 16's silent drift, again.

The icon now derives from the integer code and the label derives from the table, both out of the
SAME `weather_code`, and neither one reads the other. The forecast rows carry `code` for the same
reason.

## The pt-BR table, and what stays en-US

The condition text is pt-BR because it is the PRODUCT, the same call as the holidays' names and the
rest of the lock screen. The chrome around it stays en-US (rule 2): the popover's `Feels like`,
`Humidity` and `Wind` are labels, not content.

Intensity is kept where Open-Meteo publishes it (`Chuva fraca` / `Chovendo` / `Chuva forte`), since
collapsing 61, 63 and 65 into one word throws away a distinction the source paid for.

**An unknown code shows NO condition.** The bar prints `—` and the lock screen prints the
temperature ALONE, never an invented word. All 28 codes Open-Meteo actually emits are in the table,
so the fallback is defensive only.

## The failure paths, all measured (22/08/2026)

The lock screen's fetch writes atomically (`.tmp` plus `mv`) and refuses to publish a bad read,
because an EMPTY label on the lock screen reads as "the lock is broken":

| Input | Result |
| --- | --- |
| host unreachable | the previous cache stays, no `.tmp` left behind |
| empty body, malformed JSON | the previous cache stays |
| `temperature_2m` or `weather_code` null | the previous cache stays |
| code 42 (not in the table) | `22°C`, with no condition |
| code 0 | `Céu limpo, 22°C` |
| -3.4 | `Nevando, -3°C` |

Two details in that script that are easy to get wrong:

- **One `jq` pass with `select`**, so a response missing either field produces NO line at all
  instead of a half-formed label. `weather_code` **0** survives it: only `null` and `false` are
  falsy in jq, so the `select` does not eat a clear sky.
- **No trailing newline.** hyprlock renders the label raw and a `\n` becomes an empty second line.

The case arms are GENERATED from the same attrset the bar reads, so the lock screen and the bar
cannot drift apart again.

## The QML side reads a generated JSON

`Bar.qml` gets the table through `FileView` over `~/.config/theme/weather.json`, the same pattern
and the same reason as the palette in `Theme.qml`: a Nix-generated JSON is the ONLY path into a
hot-reload tree, since the QML is an out-of-store symlink Nix cannot template.

What guarantees a valid fetch URL is the hardcoded coordinate FALLBACK, and `blockLoading` was
DROPPED once that was measured: the palette needs it because bindings read its colors immediately,
while here nothing reads the file outside `onLoaded`, so the flag only looked like it did something.
MEASURED on 22/08/2026 in a standalone `qs`: at `Component.onCompleted` the table is still empty
and the label reads `—`, and only afterwards does `onLoaded` fill it in (`Nublado`, `Céu limpo`,
`Chovendo`). So the load IS async, the first fetch always leaves on the fallback coordinates, and
the label arrives a moment later. Since the fallback holds the same numbers as the SSOT, nothing
diverges.

That fallback is also what makes a MISSING JSON harmless, the same choice as the palette's
fallback colors: the temperature and the icon still work and only the label degrades to `—`.
Verified by hot-reloading the new QML BEFORE the JSON existed, and the pill kept working.
