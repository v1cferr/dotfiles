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

## How to

- **Add an event:** a record in `registry/holidays.json` with its rule, place, kind, applicability,
  status, `verified_at` (the day you READ the source) and source ids; add the source to `sources` if
  new. Then `python3 -I scripts/registry.py validate registry` and the tests.
- **A new year's acts:** add the year to `confirmed` of each recurring optional day the act lists
  (with its hours), and dated records for its bridge days. Extend `Audit` with the new act's items.
- **Fix a source:** change its record, set `checked_at` and `check` to what really happened.
- **A divergence:** record both sources and a `notes`; set `disputed` only when the answer itself
  changes. Never pick one in silence.
- **The UN list for a new year:** download the page and run
  `registry.py import-un page.html --year Y --checked YYYY-MM-DD > registry/observances-un.json`.
