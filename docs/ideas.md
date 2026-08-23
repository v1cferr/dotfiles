# Ideas

Things considered, references, and what has not become a decision yet. What already did is
in [history/](history/); what is still to do is in [open-items.md](open-items.md).

> Quickshell: DECIDED, I migrated everything to Quickshell. Customizable in
> QML with hot-reload; Hyprland became hot-reload too (hyprland.lua through
> mkOutOfStoreSymlink).
> For inspiration: <https://github.com/Misterio77/Foundry>
> Nix wallpapers: <https://github.com/NixOS/nixos-artwork/tree/master/wallpapers>
> Centralized themes: `home/desktop/palette.nix` (`my.theme`). nix-colors was discarded
> (archived + base16 caps it at 16 colors).

## Blue light filter and eye strain

**If hyprsunset gains a gradual transition** (the *Graduated transition* issue, opened on
08/08/2026), the 13 profiles in `home/desktop/hyprsunset.nix` collapse into 3 (day, night
and late night) and the tool interpolates. Today it jumps abruptly, and the small steps are
what disguises the jump.

**The priority order against eye strain** is the opposite of the intuition: reducing
BRIGHTNESS comes before color temperature, and night mode does not replace adequate
brightness. That is what motivated a `ddc.nix` that no longer exists: gamma darkens the signal, not
the light being emitted. The DDC/CI brightness curve was BUILT and REVERTED on 08/08/2026,
so there is no module to open; it worked, but only on the main monitor, and the HDMI TV has no automatic path. See the august
history. What is still open:

- **Progressive gamma from 18:00 on**, the next step if the color curve is not enough, and
  it is the one that would finally apply the priority above. On 13/08/2026 the post-18:00
  curve came down ~200 to 400K per step (the 2nd descent) and the BRIGHTNESS axis was left
  out on purpose: automatic dimming through gamma existed and was reverted on 08/08 along
  with the DDC.
  The Kelvin curve got close to the useful floor, since it already crosses the ~3200K
  where the color ruins media, so going further down in K makes the color worse without a
  proportional relief. If the discomfort comes back, the adjustment is gamma, not more
  orange.
- **Bias lighting**, a light behind the monitor. It is the recommendation that shows up
  most in the literature and the only one that is not software: it reduces the contrast
  between the screen and a dark wall.
- **PWM**: a monitor that dims through PWM flickers at low brightness and makes fatigue
  worse. Check whether the panels are flicker-free before lowering the backlight too far.

## NetBird: a CGNAT contingency, not a replacement

<https://github.com/netbirdio/netbird>, WireGuard with a control plane: peer discovery,
automatic NAT traversal, per-device ACL and SSO. Evaluated on 10/08/2026, the same day the
Moonlight direct access landed.

**DECISION: stay with the router's WireGuard alone. Do not switch, and do not run both.**

The framing that matters is not "switch or not", it is that the current design rests on a
single premise: **Alcans gives a real public IP**. Port forwarding, WireGuard on the router
and DDNS all three depend on it. If that changes, they fall TOGETHER, in the same minute.
NetBird is the plan for that day, and this analysis exists so it does not have to be redone
under pressure.

### Why not now

- **It requires an agent on every machine**, which is exactly what was refused: the FAI
  notebook already runs nxBender + openconnect, and the NetBird agent manages routes
  dynamically, the same class of conflict, harder to debug than a static `wg-quick`.
- **It reintroduces the relay.** It falls back to Relay/TURN when P2P fails, which is
  Tailscale's DERP under another name, the reason Tailscale went out on 08/08. And on the
  FAI network, which drops SYN-ACK, a P2P failure is the LIKELY scenario: it would relay
  precisely there.
- **The router cannot be the server.** The management side asks for "1 CPU and 2 GB"; the
  WR3000 has 128 MB of RAM and ~1.3 MB of free flash. The agent runs on OpenWrt, the
  control plane does not.
- **Self-hosting creates a circular dependency:** management + signal + relay would go to
  the PC, which is the machine you are trying to reach. Today that loop does not exist,
  since the router is a separate device that is always on. Using their cloud solves the
  circle by adding the third party back.

### What it would actually solve (and why it stays written down)

1. **CGNAT**, the trigger. With a relay, it survives what would kill everything today.
2. **Adding a peer without editing UCI by hand.** Today that is SSH into the router;
   `router-sync` is pull-only. Real friction.
3. **Per-device ACL.** Today the Sunshine rule trusts the ENTIRE `10.10.10.0/24` range, so
   the phone, the notebook and the workstation have exactly the same access. This is a real
   limitation of the current design, independent of CGNAT.

### Trigger to reopen

The home public IP no longer answering from outside. A test that does not lie (an
independent external vantage point, never from inside the LAN, because the ISP does
hairpin):

```sh
curl -s "https://check-host.net/check-tcp?host=<ip>%3A2222&max_nodes=3" \
  -H "Accept: application/json"
```

## "Everything on the router": what it already is, and what it cannot be

My idea (10/08/2026): concentrate services on the router so that nothing stops when the PC
goes down (power outages and the like).

**GOOD NEWS: the ACCESS layer already is exactly that.** These run on the router and do not
depend on the PC: WireGuard (`wg0`, the router is the server), DHCP, DNS with adblock-fast
and https-dns-proxy, firewall/SQM, and Wake-on-LAN (`/usr/bin/wake-desktop`). The PC can be
off and the VPN still comes up and the home network still works.

**What CANNOT migrate:** Jellyfin, Sunshine, Caddy, qBittorrent and Ollama. It is not a
matter of willingness, it is 128 MB of RAM and 1.3 MB of free flash. Screen streaming and
media transcoding do not fit by any order of magnitude.

**And the bottleneck in the "power went out" scenario is NOT the router, it is the PC
coming back on its own.** That is BIOS (*Restore on AC Power Loss* = Power On), not Nix,
and it is not declarable in this repo. WoL does NOT replace it: after a real power cut the
NIC loses the state armed by `ethtool`, and it only comes back if the BIOS itself keeps
wake enabled. The right order to attack it: (1) the BIOS powers back on by itself, (2) WoL
as the rescue for a normal shutdown, (3) a UPS on the router and modem if the intent is to
keep the internet up DURING the outage, but that does not turn the PC on, because the PC is
not on the UPS.

`router/uci/etherwake.conf` is DEAD CONFIG: `name='example'`,
`mac='11:22:33:44:55:66'`, the factory placeholder of the LuCI app, never filled in. What
works is `/usr/bin/wake-desktop`, with the MAC baked in. Do not trust the LuCI screen.

## DeepSeek Harness: the local agent works, the harness is the risk

<https://github.com/deepseek-ai/deepseek-harness>, an agent harness where "everything is a
plugin" over the Cordis kernel: models, tools, skills, sandbox, storage, loop and the UI are
all swappable rows in a patch tree. It ships a Web UI, a one-shot `headless` mode and a
Python SDK. Tested on 20/08/2026 against the local Ollama.

**DECISION: not adopted. It stays a scratch experiment, with no NixOS module.**

This evaluation separated two questions that look like one. "Can this machine run a local
coding agent" is now answered YES, and that answer outlives the harness. "Should dsh be the
harness" is a NO with a reopen condition.

### What the test proved, and this part is keepable

Two real tasks finished end to end with `qwen3.5` (9B) on the B580: find and fix a bug in a
file, then write a unittest suite, run it with `python3` and report the outcome. The second
took 25 s over 5 requests. The 9B never fumbled a tool schema, which is exactly what I
expected it to fail at.

The number that decides everything: the harness sends around **8.2k tokens of FIXED prefix
per turn**, 1051 of system prompt plus 7128 for 25 tool definitions (`bash`, `edit`,
`subagent`, `workflow`, `web_search`, `skill` and others). Out of a 32k window, a quarter is
spent before a single file is read. That is a ceiling on ANY local agent here, not a dsh
detail, and it is why `OLLAMA_CONTEXT_LENGTH` had to move off the 4k default.

### Why it is not adopted

- **The documented quickstart does not boot.** `npx @deepseek-ai/dsh` installs the launcher
  at 0.1.0-rc.7 and every bundle at rc.8, because a caret on a prerelease accepts it, and the
  boot dies on `--expose-internals is required for HMR service` even though the headless
  bundle marks that row `disabled: true` (confirmed with `--dump-config`). It only runs by
  calling `node --expose-internals` on `bin.js` by hand.
- **A documented config path is refused in SILENCE.** `reasoningEfforts` with the `off` key,
  documented in both of its spellings, makes the whole `llm-pi-ai` section be discarded. No
  error is printed: the only symptom is `NO_ADAPTER: no adapter registered for provider
  "ollama"` at request time, and finding it took bisecting the YAML field by field. That key
  is not cosmetic here, because with thinking ON the model drops its answer into the
  `reasoning` field and returns an EMPTY `content`, intermittently and worst right after a
  tool result. The workaround is to declare another level whose wire spelling is `none`, and
  `PARAMETER think` does not exist in Ollama 0.32.3, so it cannot be baked into the model.
- **Version 0.1.0-rc.8, one week old**, with "THERE WILL BE COMPATIBILITY-BREAKING CHANGES"
  in the README. Issues are disabled, feedback goes through Discussions.
- **It is imperative by design.** `dsh plugin` forwards to pnpm and installs into
  `$DSH_HOME/profiles` at runtime, so its plugins cannot be declared in this repo.
- **Headless approves everything.** It wrote files and ran `python3` with no gate at all, so
  it belongs in a disposable workspace and nowhere near a real checkout.

### What is worth stealing from it

The session log is append-only and records everything the model saw, context injections
included, which is the honest answer to "why did it do that". And the profile model, an
ordered stack of patch layers with `--dump-config` to inspect the composed tree before
booting, is a good idea whatever harness ends up winning.

### Trigger to look again

A tagged release that is not a release candidate, with the `npx` quickstart booting exactly
as written. Until then, the local-model half of this is served by Ollama on its own.

## The CI, and what would make it last (researched on 23/08/2026)

The question behind this section is not "is NixOS good today", it is whether this repo can keep
being the SSOT of my infrastructure until 2032. The blind spots of the GATE were closed the same
day (see the [august history](history/2026/08-august.md) and
[notes/repo/flake.md](notes/repo/flake.md)); what is below was researched and NOT decided, in the
order the research put it.

- **A Nix store cache in the CI**: `nix-community/cache-nix-action@v7`, which saves and restores
  `/nix` through GitHub's own cache. It is the option with NO vendor, which is what keeps the
  decision recorded against the Determinate installer intact (`magic-nix-cache` and FlakeHub Cache
  fail on exactly that count). Today the run fetches ~1.43 GiB of inputs and recompiles the btop
  fork every time. THE CAVEATS, and they are the reason this is not a one-liner: 10 GB of cache per
  repository with LRU eviction, and `gc-max-store-size` is mandatory or the cache grows until it is
  useless. THE CANARY RAISED THE STAKES here: it is now the heaviest job in the repo, since it
  refetches every input at HEAD, so this is the piece that would make it cheap.
- **DONE the same day, and the shape got simpler than this sketch**: the canary is
  `.github/workflows/canary.yml`, weekly, with `--recreate-lock-file --no-write-lock-file` instead of
  one `--override-input` per input. Same guarantee, one flag: every input at its branch head and the
  committed pin untouched. MEASURED at 1m41s locally, all checks passing, so today nothing upstream
  is broken. The reasoning is in [notes/repo/flake.md](notes/repo/flake.md), and the external link
  half is in [notes/repo/link-checker.md](notes/repo/link-checker.md).
- **`system.build.toplevel` in the CI: researched and NOT recommended.** A free runner has ~20 GB
  free and this closure drags Quickshell (Qt/C++) in, while the cache above caps at 10 GB. The three
  ways out are `nix-fast-build --skip-cached` plus an action that reclaims disk, a self-hosted
  runner on the Kingston itself (attractive, since the machine is always up, but on a PUBLIC repo it
  has to be restricted to `push` and never `pull_request`, or a fork runs code on my PC), or not
  doing it. Rule 8 already requires `nixos-rebuild build` before the switch, which is the same
  guarantee bought with hardware I already own.
- **Automating the `update`**: `update-flake-lock` v3 no longer installs Determinate Nix, so the
  vendor objection is gone, and Renovate does update `flake.lock`. Both trip on the PRIVATE input:
  they would need the deploy key of Plan B. Rule 13 keeps `update` as the USER, and the canary above
  is what says when it is worth running.
- **DONE the same day, and the prediction about qmllint was right**: the Lua goes through `lua-ls`
  reading the repo's own `.luarc.json`, the loose Python through `ruff`, and the QML through a parse
  check that keeps ONE qmllint category, because the rest of it produced 2267 findings that are
  almost all false. The measurements are in [notes/desktop/quickshell.md](notes/desktop/quickshell.md).
- **Tags for the milestones.** There are two tags in the repo and neither marks a state. Tagging the
  cutover, the GPU swap and the day impermanence lands makes "the state that worked" addressable,
  which is worth more the further 2032 gets.
- **The disaster-recovery drill, and stage 1 of it LANDED the same day**: `nix build .#vm-boot`
  boots this host in QEMU weekly and asserts the config was applied
  ([notes/repo/vm-boot.md](notes/repo/vm-boot.md)). What is still an idea is the other half, the one
  that needs a human: `nix build .#nixosConfigurations.nixos-kingston.config.system.build.vmWithDisko`
  formats virtual disks with the REAL disko layout, and a clean clone plus the age key from the vault
  is what proves the piece that is not in git. `nixos-rebuild build-vm` is the wrong tool for the
  disk half, it hangs waiting for the root partition on a disko layout (disko issue #668).
