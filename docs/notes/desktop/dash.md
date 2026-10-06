# The glance band on the standing monitor

`modules/home/desktop/quickshell/dash/`. Everything that belongs to the band lives in that one
folder: the panel (`Dashboard.qml`), its pieces (`Tile.qml`, `Horizon.qml`, `CiList.qml`), the CI
feed (`Ci.qml`) and, under `scripts/`, the shell behind it (`ci-status.sh`, packaged as
`ci-status-json` in `modules/home/desktop/quickshell.nix`). The shell sits in its own subfolder so
the folder reads as QML views on top and build inputs below. It is the top 30% of the standing secondary, reserved so
that no window lands in it.

The band is a part of the Quickshell tree and not a Nix module of its own on purpose: the QML has to
sit under the `mkOutOfStoreSymlink` that becomes `~/.config/quickshell`, or the `root:/` imports
and the hot reload stop working, and it reads every system number from the bar's Scope (`host`).

**Why it exists.** A 27" panel on its pivot is 597 mm tall, so its top third sits ABOVE eye level
for anyone sitting at the desk, while the ergonomic target is 0 to -30 degrees below the
horizontal. A window up there is a neck problem, not a layout preference. The split is 30/70 on
purpose: 768 px of band against 1792 px of work area, on the 2560 logical px that the 1920 px
panel becomes at `scale = 0.75`.

**How the space is taken: `exclusiveZone`, not a gap.** A workspace rule with
`gaps_out = { top = N }` reserves the same strip, and it was the first attempt, but N would then
have to be kept in sync BY HAND with the panel's height, and it only covers the workspaces it
names. A layer surface declares its own height and Hyprland tiles below it, so ONE number governs
both. That number subtracts the bar's own zone (`host.barExclusiveZone`) and the two 4 px margins,
which is what makes the bar and the band together add up to the 30%.

**What earns a place.** The top of a standing screen is for what is read in two seconds and never
clicked: the time, the month, the machine's vitals and what is playing. Everything that takes
a click stays in the 70%. The notification FEED is deliberately not there, only a bell with the
count: a feed in the eyeline is the opposite of a glance surface, so the centre opens on a click
and nowhere else.

**The vitals are tiles, not meter rows.** CPU, RAM, DISK, GPU, TEMP and NET sit in a 3x2 grid
(`dash/Tile.qml`) with a 36 px value, under an `UP · LOAD` line. The first version reused the
popovers' `MeterRow`, whose 10 to 12 px text is sized for a hover a hand away; at `scale = 0.75`
it was unreadable from the chair and left the left column half empty. GPU is power against its
own cap, because the Arc publishes no busy percentage, and NET is download against the link speed.

**No new data.** Every number is already collected in `Bar.qml` for the bar and its popovers, so
the component takes that Scope as `host` and reads it. The month is `monthCells()`, the same
function the year popover renders, at 18 px instead of 9, with the days already gone dimmed so the eye lands on what is ahead.

**The horizon.** The panel's bottom edge is the CPU of the last 2 minutes, in `dash/Horizon.qml`.
It divides the glance zone from the work zone with the one signal worth catching out of the corner
of an eye, instead of with a decorative rule. It is its OWN component and not the shared
`Sparkline`: the band wants a gradient crest, a brighter newest bar and an animated height, and
none of that should follow the widget into the popovers, where a flat bar is the right answer.

It carries a `CPU · 2 MIN` caption because the first person to see it read the shape as audio. A
graph with no label invites the wrong guess, and the label costs 12 px of text.

**Its ceiling follows the peak.** On a fixed 0 to 100 scale an idle desktop at 8% drew a flat line,
so `scaleTop` is the window's peak plus 25%, rounded up to a step of 10, never under 20. The
caption carries that ceiling (`CPU · 2 MIN · 40%`), so a tall bar is never read as a busy machine.

**It SCROLLS, it does not morph, and that is the whole difference.** Animating 60 bar heights on
every sample makes the graph writhe for 220 ms and then sit still, which reads as a stutter even
though nothing is dropping frames (`qs` was at 3% of a core while doing it). A new sample shifts the
data one step LEFT, so the track jumps one step RIGHT at that same instant and walks back over
exactly `sysInterval`, and the pixels never jump: one animated property instead of sixty, and
motion that never stops. The step is `width / (window - 1)` and not `width / window`, because the
track has to be ONE step wider than the viewport or the left edge shows a sliver of nothing at the
start of every cycle.

MEASURED: 3% of a core morphing against 7% scrolling, on a 144 Hz panel. The band is drawing every
frame now, forever, which is what that difference buys. If it ever needs to stop costing that, the
cheap variant is the same slide over 600 ms with the graph at rest for the remaining 1.4 s.

**The date block.** The clock shows HH:mm:ss at one size, then the weekday spelled out, then an ISO
line (`2026-09-15 · Setembro · W38`). The order is deliberate: the weekday is what a person wants
off a clock, and the ISO date plus the ISO-8601 week are the precise record underneath. `isoWeek()`
counts the week against the year its THURSDAY falls in, which is what puts 01/01 on week 53 of the
year before when it lands on a Friday.

**`host` is NOT a required property, and that is not sloppiness.** Quickshell's `Variants` creates
the delegate with `modelData` as the only initial property, so a SECOND required property fails the
creation with `failed to create variant with object` and the layer never appears at all.

## The CI pages: the right column rotates

The month shares its column with two CI pages, one at a time: **month, GitHub Actions, the FAI
GitLab**, every 15 s, with dots beside the title that say where the rotation is and jump on a click,
flanked by `‹ ›` arrows (`PageArrow.qml`); the mouse wheel over the column steps the pages too.
The pointer over the column HOLDS the page, because reading a row must not be a race against the
timer. The clock and the vitals never rotate: they are what the band is for.

**One feed, one schema.** `ci-status.sh` (built as `ci-status-json`, so shellcheck runs at build
time, rule 7) asks both forges and prints ONE JSON in which a run is `{repo, name, ref, state,
event, created, url}` and `state` is one of six words. The QML never learns that GitHub says
`completed/failure` and GitLab says `failed`. A source that fails reports `{ok: false, error}` and
never hides the other one. `Ci.qml` is a singleton, so it polls once whatever the number of
screens: every minute while something runs, every three otherwise, which is about 15 API calls a
poll and far from GitHub's 5000 an hour.

**What counts as "recent".** Repos pushed in the last 7 days are the candidates, and from each one
the latest run of every workflow created in that window. Dependabot's update jobs (event `dynamic`)
are dropped: they are bookkeeping, not CI.

**What a run carries.** Besides its state, every run brings the commit or PR title that triggered
it, who did, when it started and ended, the attempt, and for a failure the first failed job and
its failed step (GitLab has no steps, so it gives the stage and the failure reason). The failure
costs one extra API call, and only failures pay it; GitLab also needs one call for the pipeline and
one for the commit title, since its list endpoint carries neither. A poll takes about 12 s.

**The row and the card.** A row is the repo, the title of the run that leads it (the worst one, not
the newest), and the workflows as tinted chips. A click opens the repo's CARD in place of the list
(`CiDetail.qml`): one box per workflow with state, ref, duration (live while it runs), title,
trigger, author, age, the attempt when it is a re-run, and in red `job › step` when it broke. A
click on a box opens that run in the browser, and `‹` goes back. While a card is open the rotation
stops, and the card closes itself 20 s after the pointer leaves, so the column never stays parked.

**One row per repo.** The first version had a row per workflow, and `dotfiles` filled five rows
saying one thing. A row now wears the WORST state of its workflows (failure, running, queued,
cancelled, skipped, success, in that order), lists each workflow tinted by its own state so the
broken one is found without a click, and a click opens the run that is wrong, not the newest one.
Only a running glyph breathes, so motion itself means "still going".

**GitHub** is `gh`'s own login, the same token git already uses, so there is no second credential.
It covers every repo the account can see, including the ones where it is a collaborator.

**The FAI forge is GitLab, and it is only reachable on the VPN.** The FAI repos on GitHub run no
Actions; the pipelines live on `git.sup.fai.ufscar.br`, the GitLab CE on the FAI workstation
(which replaced Forgejo on 05/10/2026), behind its Caddy. The API answers this machine directly
over the VPN, so the script talks to it over HTTPS and never through `ssh workstation`. It reads
a `read_api` token, `fai_gitlab_token`, which is user-readable in `/run/secrets` because the
script runs as the quickshell user. Off the VPN the name still resolves, so one 4 s probe decides
it, instead of a timeout per project.

**Off the VPN it shows the last good picture.** Every good answer of a source is stamped (`asOf`)
and kept in `~/.cache/ci-status/`, and a failed one serves that copy marked `stale`, with an
`offline · 2 h` badge in peach on the page, so old data never passes for live. The page only
leaves the rotation when the forge has never answered at all. A missing or refused token stays in the rotation with a line that says which, because
that one is mine to fix.

## The FAI pipelines without the VPN: a pipeline hook through the tunnel

The API is pull and lives behind the VPN, so the band gets the FAI pipelines PUSHED instead: each
GitLab project sends its **Pipeline Hook** to `https://ci.v1cferr.dev/hooks/gitlab`. The workstation
reaches the internet like any server, so nothing on it changes beyond the per-project webhook,
which is GitLab configuration and not the machine's.

```text
git.sup (FAI) --Pipeline Hook--> ci.v1cferr.dev (Cloudflare edge, Access: service token)
                                      |  tunnel, outbound from here
                                      v
                                 127.0.0.1:9123 webhook (checks X-Gitlab-Token)
                                      |  ci-webhook-store: payload -> the band's run schema
                                      v
                                 /var/lib/ci-webhook/gitlab/<repo>__<ref>.json
                                      ^  read by ci-status-json when the API does not answer
```

**Two gates, one per layer.** At the edge, the `ci` hostname has an Access app whose only policy
is a SERVICE TOKEN (`gitlab-webhook`), and the GitLab webhook carries its `CF-Access-Client-Id` and
`CF-Access-Client-Secret` as custom headers. Behind it, the receiver only runs the store when
`X-Gitlab-Token` matches `fai_gitlab_webhook_token`. That token reaches the receiver through
`LoadCredential` and webhook's `credential` template function, so it is never in the store, and a
second rule demands a non-empty header, because `credential` yields "" when the file is missing.
The template uses Go's backtick strings on purpose: `builtins.toJSON` escapes a quote to `\"`,
and the template parser then refuses the whole file (caught by the end-to-end test below).

**The schema is the API's.** `ci-webhook-store` (`dash/scripts/`) maps the hook payload onto the
same run object `ci-status.sh` prints (merge request pipelines become `!N` there too, the failed
build gives `job › stage · reason`), keyed by repo and ref. Hooks can arrive out of order, so an
OLDER pipeline id never overwrites a newer one. Its files are 0644 in a 0755 `StateDirectory`,
because `ci-status-json` runs as me.

**Which source wins.** With the VPN up the API is the truth (`via: api`). Without it, the hook
copy is served live (`via: webhook`, a dim badge on the page). Only when neither has anything does
the stale cache answer, badged `offline`. The receiver is pure push, so it only knows pipelines
that ran AFTER the webhook was configured; the API remains the backfill.

**Self-activating.** `ci-webhook.nix` is inert until `fai_gitlab_webhook_token` exists in sops, and
the host's `ci` ingress entry follows `services.webhook.enable`, so the tunnel never maps the name
to a closed port.

Tested end to end on 06/10/2026 with the real binary and hook file (webhook 2.8.3): right token
200 and a file in the run schema, wrong, empty or missing token 403, and the token absent from
the verbose log.
