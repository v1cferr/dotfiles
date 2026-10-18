# The verified calendar

The calendar the bar opens from the time and the date. Since 18/10/2026 its holidays come from a
**holiday registry**: structured, versioned, sourced and tested, instead of a hand list inside
`Bar.qml`. The registry lives in `modules/home/desktop/calendar/`; the panel is
`modules/home/desktop/quickshell/bar/CalendarPopover.qml`.

```text
official sources ──► registry/*.json (by hand, reviewed) ──► registry.py build (Nix, at build time)
                                                                  │
                     ~/.config/theme/calendar.json ◄──────────────┘
                                  │
                     Quickshell (CalendarModel) ──► CalendarPopover.qml, the band's month card
```

Nothing reads the network when the panel opens: the data is a file Nix wrote. A source that changes
is noticed by a weekly workflow, which never edits the data by itself (below).

## The model

Each event keeps apart four things a calendar website usually blends:

| Field | What it says | Values |
| --- | --- | --- |
| `rule` | WHEN | `fixed` (month, day), `easter` (offset from Easter Sunday), `date` (one dated act), `range` (several days) |
| `jurisdiction` | WHERE | `BR`, `BR-SP`, `BR-SP-SAO-CARLOS`, `UN` |
| `kind` | WHAT it is in law | `civil_holiday`, `religious_holiday`, `optional` (ponto facultativo), `optional_partial`, `observance` |
| `applicability` | FOR WHOM | `general`, `federal_admin`, `state_admin`, `municipal_admin`, `municipal_education`, `observance` |

Plus `status`, `verified_at` (the day the source was actually read), `basis` (the act and article),
`sources` (ids into the source table, each with title, URL, authority, document id and when it was
checked), `years` (when a law took effect), `confirmed` (per-year confirmation by an annual act,
with its own sources and hours), `annual_act`, `partial` (`{"until": "14:00"}`), `notes`.

**An optional day is never `general`.** A ponto facultativo in the city hall's portaria frees the
city's own staff, and the federal one frees federal staff; neither gives a private employee a day
off. The validator refuses an optional day marked `general`, and a UN date that is anything but an
observance.

**The same day can hold two records, on purpose.** Corpus Christi is a municipal holiday in São
Carlos AND a federal optional day; Cinzas is optional until 12:00 for the city and until 14:00 for
the federal administration. They are different facts from different acts, so both are kept.
Inheritance never duplicates: a national holiday is one record, valid wherever you are.

### Status

| Status | Means | Example |
| --- | --- | --- |
| `verified` | read in an official source on `verified_at` | Tiradentes (Lei 662/1949) |
| `calculated` | a law fixes the holiday; the DATE of that year comes from the computus | Corpus Christi 2027 |
| `pending` | the date is computable but an annual act must still declare it | federal Carnaval 2027 |
| `stale` | the source moved or could not be re-read in time | (none today) |
| `disputed` | official sources disagree in a way that changes the answer | (none today) |

`occurrence_status()` derives the per-year status: a year an act `confirmed` takes the act's
sources; an `annual_act` event without one is `pending`; an Easter-based law holiday is
`calculated` outside a confirmed year. A future year never inherits a ponto facultativo.

### Dates

Civil dates only (`datetime.date`): no time of day, so no time zone or daylight saving can move a
holiday. Easter is the anonymous Gregorian algorithm, tested against published dates (2000, 2019,
2024 to 2028, 2038). A `fixed` 29/02 has no occurrence in a common year instead of a shifted one,
and Carnaval's Tuesday on 29/02/2028 is a test of its own.

## The sources (read 18/10/2026)

| Source | Read how | Result |
| --- | --- | --- |
| [Prefeitura de São Carlos, feriados](https://www.saocarlos.sp.gov.br/index.php/conheca-sao-carlos/115443-feriados.html) | curl, the chain completed through AIA (the server omits its intermediate) | the 2026 list, citing Portaria 2083/2025 and Lei 10.257/1990 |
| [Portaria nº 2083/2025](https://www.saocarlos.sp.gov.br/files/Portaria%202083_25.pdf) | the PDF's text | 25 items, for the municipal executive's own staff |
| [Lei Municipal nº 10.257/1990](https://www.saocarlos.sp.gov.br/images/stories/pdf/2014/expediente/lei10257-digital.pdf) | a scan, read by OCR | the four religious holidays: Sexta-Feira da Paixão, Corpus Christi, São Carlos Borromeu, 15 de Agosto |
| [Portaria MGI nº 11.460/2025](https://www.in.gov.br/web/dou/-/portaria-mgi-n-11.460-de-29-de-dezembro-de-2025-678388627) | the DOU's text through Sigepe Legis | national holidays and federal optional days of 2026 |
| [Lei 662/1949](https://www.planalto.gov.br/ccivil_03/leis/l0662.htm), [6.802/1980](https://www.planalto.gov.br/ccivil_03/leis/l6802.htm), [9.093/1995](https://www.planalto.gov.br/ccivil_03/leis/l9093.htm), [14.759/2023](https://www.planalto.gov.br/ccivil_03/_ato2023-2026/2023/lei/l14759.htm) | Planalto, revoked wording skipped | the national civil holidays; religious ones are municipal law |
| [Lei SP 9.497/1997](https://www.al.sp.gov.br/repositorio/legislacao/lei/1997/lei-9497-05.03.1997.html) | ALESP answered 503 to two clients | NOT re-read; 9 July confirmed by the municipal portaria |
| [UN, International Days and Weeks](https://www.un.org/observances/list-days-weeks) | the page's rows, imported | 248 observances for 2026 (249 rows, one listed twice) |

A search on 18/10/2026 found no later act changing Portaria 2083/2025.

### What the audit corrected

- **Good Friday is not a national holiday by law.** The old list had it as national. Lei 9.093/1995,
  art. 2º, makes it a religious holiday declared in MUNICIPAL law, and São Carlos declares it. The
  MGI portaria still calls it "feriado nacional": the record keeps both sources and the note, and it
  is a holiday in São Carlos in either reading.
- **Corpus Christi's basis is Lei 10.257/1990**, which revoked Lei 10.219/1989 and the contrary
  provisions. The old note cited a Lei 7.502/1974 for which no source was found.
- **04/11 is the patron's religious holiday** (São Carlos Borromeu, Lei 10.257/1990), published by
  the city as its anniversary. Both names are recorded.
- **Carnaval and Cinzas are optional days for two administrations**, with different hours, never
  a holiday and never for everyone. The old list called them national optional days.
- **Teachers' Day (15/10) applies only to the municipal school network**, and its underlying law was
  not found, so it is recorded for 2026 only, as published.
- **The bridge days (20/04, 05/06, 10/07, 03/11) and the year-end ones are the 2026 acts' own**, and
  are not projected into other years.

### The 2026 audit

The test `Audit2026` asserts every item of Portaria 2083/2025 against the expansion: its date, kind,
jurisdiction and applicability, and that it is verified. It also asserts 14 general holidays in São
Carlos in 2026, the city's own count.

| Date | Event | Kind | For | Source | Status |
| --- | --- | --- | --- | --- | --- |
| 01/01 | Confraternização Universal | civil holiday | everyone | Lei 662/1949 | verified |
| 16/02, 17/02 | Carnaval | optional | municipal staff; federal staff | Portaria 2083/2025; Portaria MGI 11.460/2025 | verified |
| 18/02 | Cinzas | optional until 12:00 / 14:00 | municipal / federal staff | same | verified |
| 03/04 | Paixão de Cristo | religious holiday | everyone | Lei 10.257/1990 (and both portarias) | verified |
| 20/04 | (bridge) | optional | municipal and federal staff | both portarias | verified |
| 21/04 | Tiradentes | civil holiday | everyone | Lei 662/1949 | verified |
| 01/05 | Dia Mundial do Trabalho | civil holiday | everyone | Lei 662/1949 | verified |
| 04/06 | Corpus Christi | religious holiday; also a federal optional day | everyone; federal staff | Lei 10.257/1990; Portaria MGI | verified |
| 05/06 | (bridge) | optional | municipal and federal staff | both portarias | verified |
| 09/07 | Revolução Constitucionalista | civil holiday (state) | everyone | Lei SP 9.497/1997 via Portaria 2083 | verified (law not re-read) |
| 10/07 | (bridge) | optional | municipal staff | Portaria 2083/2025 | verified |
| 15/08 | Nossa Senhora da Babilônia | religious holiday | everyone | Lei 10.257/1990 | verified |
| 07/09 | Independência do Brasil | civil holiday | everyone | Lei 662/1949 | verified |
| 12/10 | Nossa Senhora Aparecida | civil holiday | everyone | Lei 6.802/1980 | verified |
| 15/10 | Dia do Professor | holiday | municipal school network only | Portaria 2083/2025 | verified |
| 28/10 | Dia do Funcionário / Servidor Público | optional | municipal / federal staff | both portarias | verified |
| 02/11 | Finados | civil holiday | everyone | Lei 662/1949 | verified |
| 03/11 | (bridge) | optional | municipal staff | Portaria 2083/2025 | verified |
| 04/11 | Aniversário de São Carlos | religious holiday | everyone | Lei 10.257/1990 | verified |
| 15/11 | Proclamação da República | civil holiday | everyone | Lei 662/1949 | verified |
| 20/11 | Consciência Negra | civil holiday | everyone | Lei 14.759/2023 | verified |
| 24/12 | (Christmas Eve) | optional; federal after 13:00 | municipal / federal staff | both portarias | verified |
| 25/12 | Natal | civil holiday | everyone | Lei 662/1949 | verified |
| 31/12 | (New Year's Eve) | optional; federal after 13:00 | municipal / federal staff | both portarias | verified |

**Still pending:** the State of São Paulo's own optional days (a yearly decree for state staff) are
not in the registry; Lei SP 9.497/1997 must be re-read when ALESP answers; every optional day of
2027 waits for its acts, as they are published in December.

## The panel

`CalendarPopover.qml` opens on a hover of the time or the date, pins on a click, closes on Escape
or a click outside: the bar's coordinator, unchanged. It is hung from the logo, so the time and the
date open the same panel in the same place.

| View | Holds |
| --- | --- |
| The year | the 12 months, the current one on a surface of its own; the upcoming events beside them |
| A month | one month at about 140 x 87 px a cell, the events named inside; the selected day's detail beside it |

A month's name, or any day, focuses that month (the day selected); `Year` goes back; `‹ ›` step a
year in the year view and a month in the month view, across the year's turn; `Today` returns to
today. The year chosen stays until another is chosen, across closes. The detail lists every event
of the day after the filters, each with kind, scope, for whom, basis, status (`Verified · checked
18/10/2026`, `Calculated date`, `Pending its annual act`), notes, and its sources: a click opens the
official publication in the browser. A day whose events are all filtered out says how many hide.

**Geometry from the screen, not its name.** Four columns where the room is 1200 px or more, three
below; a cell from the month's width, never under 26 px wide or 24 px high, the digits at 12 px;
past the screen's height the body scrolls and the header, the filters and the legend stay. Measured
on 18/10/2026 through IPC, no cursor moved:

| Screen | Panel | Grid | Cells |
| --- | --- | --- | --- |
| ASUS, 2560 x 1440 | 1320 x 790 at x 620 (centered on 1280) | 4 x 3, the upcoming list beside | about 30 x 27 px |
| LG standing, 1080 x 1920 | 960 x 1557 | 3 x 4, the upcoming list below, the legend wrapped | about 31 x 28 px |

## The grid

A day carries independent signals, each its own shape, never one more color:

| Signal | Means |
| --- | --- |
| a filled chip in the scope's color | a holiday for everyone |
| an outlined chip | an optional day, or a holiday for a restricted group (Teachers' Day) |
| a teal dot under the number | an observance |
| a small corner dot | more than one event that day; the detail lists them |
| a ring around the whole cell | today |
| a neutral fill | the selected day |

Scope colors are the bar's `scopeColor()`: red Brasil, blue São Paulo, mauve São Carlos, teal
International. Today is a RING because a fill would collide: `accent` and `blue` are the same hex in
Tokyo Night, so a filled today was pixel for pixel a São Paulo holiday. A day's main signal is its
strongest event (a holiday for everyone, then a restricted one, then an optional day, then an
observance); Carnaval's two records keep one outline and the corner dot.

The band's month card reads the same data through `monthCells()` with the default filters.

## The keyboard

While the panel is PINNED (a click on the time or the date; a hover never takes the keyboard):

| Key | Year view | Focused month |
| --- | --- | --- |
| ← → | the day before / after | the same, the month following the day |
| ↑ ↓ | a week before / after | the same |
| Page Up / Down | the year before / after | the month before / after |
| Enter or Space | focus the selected day's month | |
| Home | today | today |
| Escape | close | back to the year |

`BarPanel` offers each key to the panel first (`keyPressed`); one the panel leaves unaccepted falls
through, Escape closing, so every other panel keeps its Escape. A day's step is computed at local
noon, so it crosses months, years and 29/02 with no special case. Written on 18/10/2026 and not yet
driven with real key presses: the test was stopped because a game was in fullscreen.

## Filters

Two independent sets, `Holidays.filters`: WHERE (São Carlos, São Paulo, Brasil, International) and
WHAT (holidays, optional days, observances). The defaults: the three places that hold in São Carlos,
holidays and optional days; International and observances off, since the UN lists about 250 days.
`Reset` appears when they differ. They drive the grid, the upcoming list and the detail at once,
and last for the shell's session.

## Offline, and what is computed when

The panel reads `~/.config/theme/calendar.json`, which Nix built from the registry for 2024 to 2032;
a year outside that range says it has no registry data. Nothing touches the network on open. The
year's map is recomputed when the year, a filter or the file changes, never per frame; the day's
turn moves `today` through the Bar's clock. After an edit to the registry, a `rebuild` writes the
new file and the panel re-reads it on its next open. It re-reads on EVERY open on purpose: a rebuild
swaps the symlink to a new store path, which the file watcher did not see on 18/10/2026, and a hot
reload kept the old text, so the detail showed a source list from before the rebuild.

## The source watch (GitHub Actions)

`.github/workflows/holidays.yml`, Wednesdays, and by hand. It fingerprints the TEXT of each source
the registry cites (`registry.py check-sources`, curl and openssl, the runner's own) and compares it
with `registry/sources.lock.json`:

- **unchanged:** nothing happens;
- **changed, missing markers or unreachable:** ONE issue, opened or commented, with the table. The
  registry is never edited: a page that changed may be a new act or a new menu, and only a person
  reading it can tell.

São Carlos' server omits its intermediate certificate: the fetch takes the issuer from the leaf's
AIA field and verifies the chain with it, as a browser does, never skipping verification. Its
portal page is fingerprinted only between `Relação de feriados` and `Portarias:`, so a new menu
cannot raise an alarm, and losing the markers can. Planalto resets a connection for an unknown
agent, so the agent is browser-shaped and still names the project.

On 1 December the same workflow opens the next year's audit checklist. Validation on every push is
the flake check `holiday-registry` (`nix flake check`, the CI's quality gate). After a review,
refresh the lock with `registry.py check-sources registry --lock registry/sources.lock.json
--update-lock`.

## Tests, and what was not

`modules/home/desktop/calendar/scripts/test_registry.py`, 20 tests, run by the flake check: the computus, Carnaval on 29/02/2028,
a fixed 29/02 that never shifts, a range across the year's turn, the schema's refusals, every item
of Portaria 2083/2025, the 14 general holidays, Good Friday's two sources, the two Corpus Christi
records, the restricted Teachers' Day, a future optional day pending, Consciência Negra from 2024,
observances only for the year read. Two consecutive source checks on 18/10/2026: nine unchanged,
ALESP 503.

Seen on screen on 18/10/2026: the year view (ASUS and LG), April focused with 03/04's detail and
sources, May with International and observances on. Not tried by hand: the hover and click paths
themselves (the IPC opens the same panel), a source link opening, and the day's turn at midnight.

## Checking it without a mouse

`qs ipc call bar panel cal` opens the year; `qs ipc call bar calendar 2026-04-03` focuses a day;
`qs ipc call bar calendarFilter un` flips a filter (`reset` restores them); `qs ipc call bar panelOn
cal DP-2` opens it on a named screen; `qs ipc call bar close` closes it.

## How to

- **Add an event:** a record in `registry/holidays.json` with its rule, place, kind, applicability,
  status, `verified_at` (the day you READ the source) and source ids; add the source to `sources` if
  new. Then `python3 -I scripts/registry.py validate registry` and the tests.
- **A new year's acts:** add the year to `confirmed` of each recurring optional day the act lists
  (with its hours), and dated records for its bridge days. Extend `Audit` with the new act's items.
- **Fix a source:** change its record, set `checked_at` and `check` to what really happened.
- **A divergence:** record both sources and a `notes`; set `disputed` only when the answer itself
  changes. Never pick one in silence.
- **A divergence that changes the answer** (two acts give different dates): `disputed`, both sources, and a
  note; the detail shows it in the warning color until a person settles it.
- **The UN list for a new year:** download the page and run
  `registry.py import-un page.html --year Y --checked YYYY-MM-DD > registry/observances-un.json`.
