# GitHub settings

What protects this repo lives partly on GitHub and not in git. This page is the record of those
settings, so a rebuilt repo (or a fork) can get them back, and the files under
[`.github/rulesets/`](../../../.github/rulesets/) are their declared form (rule 3).

## The `history` ruleset

[`.github/rulesets/history.json`](../../../.github/rulesets/history.json), created on 27/09/2026.
It blocks **deletion** and **force-push** on `nixos`, `main` and `arch`.

**Why these three and not only `nixos`**: `main` and `arch` are ORPHAN histories of the machines
before NixOS, and a deleted orphan branch is gone for good, since nothing else points at its
commits. They receive no pushes, so the rule costs nothing there.

**No bypass actor, on purpose.** The only person who pushes here is the admin, so an admin bypass
would be a rule that never applies to anyone. An emergency force-push means disabling the ruleset
first, which is a deliberate click in Settings instead of a flag typed by reflex.

**No required status check, and no required review.** Both are what a team template adds, and
both break a solo repo: a required review has nobody to approve it, and a required check turns
every direct push to `nixos` into a PR. The pre-commit hook already runs the same gate before the
commit, and the CI re-runs it after the push.

Applying a change to the file, with the ruleset found by its NAME, which is the file's own key:

```sh
id=$(gh api repos/v1cferr/dotfiles/rulesets --jq '.[] | select(.name == "history") | .id')
gh api -X PUT "repos/v1cferr/dotfiles/rulesets/$id" --input .github/rulesets/history.json
```

On a new repo the call is a `POST` to `repos/<owner>/<repo>/rulesets` instead. Check what a branch
actually gets with `gh api repos/v1cferr/dotfiles/rules/branches/nixos`.

**The canary guards the drift.** Its `rulesets` job diffs every file in `.github/rulesets/` against
what GitHub enforces, each Monday, and a mismatch reaches the phone like any canary failure. That
is the failure the missing bypass invites: a ruleset disabled for an emergency and never turned
back on, which nothing else would ever report. `bypass_actors` stays out of the diff, since a
read-only token gets it as `null`. MEASURED before the commit: the live ruleset matches the file,
and flipping `enforcement` in the file makes the diff fail.

## Secret scanning

Secret scanning and its **push protection** are ON (checked 27/09/2026 through
`gh api repos/v1cferr/dotfiles --jq .security_and_analysis`). Push protection refuses a push
carrying a token from a known provider, on the server, before it lands.

**The two advanced toggles do not exist for this repo.** Non-provider patterns and validity checks
were turned on through the API on 29/09/2026: the `PATCH` answered 200 and both stayed `disabled`,
with no error. They are sold as part of GitHub Secret Protection, for ORGANIZATION-owned
repositories, and a user-owned repo silently ignores the request. Nothing is lost by it: the
generic shapes they would add (private keys, connection strings, generic API keys) are in the
default gitleaks rules this repo already runs, below.

That covers the known providers and nothing else, and it only sees pushes. A generic token (the
`rpcd_token` of 08/08/2026 was one, see [router-hardening](../../guides/router-hardening.md)) walks
straight through it, so the repo adds two layers of its own, both running gitleaks:

- **The `gitleaks` hook** scans the STAGED diff before each commit, and the whole tree inside
  `nix flake check`, since the gate's throwaway repo stages everything. MEASURED: a clean tree
  passes, and a planted `ghp_` token is refused.
- **The canary's `secrets` job** scans every commit once a week, which is what catches a
  `--no-verify` commit or a rule that a newer gitleaks learned. Its version is the devShell's, so
  the hook and the job never disagree about the rules.

**The two known findings live in [`.gitleaksignore`](../../../.gitleaksignore)**, by fingerprint
(`commit:file:rule:line`), so each one silences that exact spot and nothing else. The first full
scan on 27/09/2026 read 1419 commits and found exactly these two, both already dealt with:

| Commit | What it is |
| --- | --- |
| `a2a7b6f` | the router's `rpcd_token`, a real credential: rotated, and the sync redacts it since `0277caf` |
| `dd73404` | a `curl -H "Authorization: Bearer ..."` placeholder in an `.env.example` |

A new finding means one of two things. A real credential gets ROTATED first, since it is already
public and rewriting history is not an option (the `history` ruleset exists to forbid it). A false
positive gets its fingerprint appended here, with its line in the table above.

### A public address is a leak no credential scanner sees (29/09/2026)

Every layer above looks for CREDENTIALS. What a public repo of infrastructure leaks more easily is
a MAP: the public IPv4 of the house, or of someone else's network. So [`.gitleaks.toml`](../../../.gitleaks.toml)
extends the default rules with `public-ipv4`, and the same hook and the same canary job run it.

The regex only accepts real octets (0 to 255, no leading zero), which already drops most version
numbers and dates. What remains legitimate is an ALLOWLIST, one block per reason, and each block
carries a `# review-by:` date that `dead-config --expired` reads in the canary, which is rule 22
applied to this list too. The first pass, measured over the tree and every commit:

| Allowlist | Review by | Why |
| --- | --- | --- |
| not a public address | never | RFC 1918, loopback, CGNAT, link-local, multicast, the TEST-NETs |
| public DNS resolvers | 2027-09-29 | upstreams and probes, named on purpose |
| two version numbers | 2027-09-29 | codex `1.2.92.147`, a postgres tag |
| the Arch-era package lists | 2027-09-29 | history-only files, full of versions |
| this house, and addresses that attacked it | 2027-09-29 | the home IP is already public through the DNS of `ssh.v1cferr.dev` |
| FAI and UFSCar | **2026-12-31** | someone else's network, kept until I decide if it belongs in a public repo |

With it in, the full history scan reads no leaks. MEASURED in the other direction: a staged file
with a new public address fails the hook, while an FAI address, a LAN address, a TEST-NET example
and a version number in the same file pass. SVGs are skipped by gitleaks' own global allowlist,
which is why the digits of a path in `razer.svg` never needed an entry.

## OpenSSF Scorecard

[`.github/workflows/scorecard.yml`](../../../.github/workflows/scorecard.yml) grades the repo's
supply chain every Monday, and again whenever a ruleset changes. The SARIF lands in the Security
tab and `publish_results` makes the score public, at
<https://scorecard.dev/viewer/?uri=github.com/v1cferr/dotfiles>. That score is the METRIC for this
side of the repo: a number with a date, instead of "I think the CI is safe".

**Most of the checks were already paid for** before the workflow existed: actions pinned by hash
(Pinned-Dependencies), a read-only token by default (Token-Permissions), Dependabot on the actions
(Dependency-Update-Tool), zizmor on every workflow (Dangerous-Workflow). The `history` ruleset
feeds Branch-Protection, and [`SECURITY.md`](../../../SECURITY.md) with private vulnerability
reporting turned on (27/09/2026) feeds Security-Policy.

**Some checks stay low ON PURPOSE**, and chasing them would be theatre:

| Check | Why it stays low |
| --- | --- |
| Code-Review | one maintainer pushing straight to `nixos`; nobody else could review |
| Branch-Protection | partial for the same reason: no required review, no required check |
| Fuzzing, Packaging, Signed-Releases, CII-Best-Practices | a machine config, not a released artifact |
| Contributors | a personal repo |

**The first score, 27/09/2026: 6.5.** Beyond the low checks above, two had something to act on:
License is 0 because the repo has no license file, which is a decision about reuse and not a CI
fix; and Vulnerabilities is 8 over two lodash advisories (GHSA-f23m-r3pf-42rh, GHSA-r5fr-rjxr-66jc,
fixed in 4.18.0), both from a `lodash-es@4.17.23` that the site's `pnpm-lock.yaml` pulls in
transitively. The lodash one was fixed the same day with a pnpm override, whose reason and removal
condition live in [site](site.md). The license went in the same day too ([license](license.md)), and the
re-run gave **6.9**, with both License and Vulnerabilities at 10.

**SAST moved out of that table on 30/09/2026, and the reason it was in was half true.** CodeQL has
no Nix analyser, but this repo is not only Nix: it reads the checkers' Python, the site's TypeScript
and the workflows themselves (the `actions` language), which is real coverage and not a badge.
[`codeql.yml`](../../../.github/workflows/codeql.yml) runs the three on every push and weekly, with
`build-mode: none`, since none of them needs a build and a build would mean Nix on the runner for
nothing. The same day [`SECURITY.md`](../../../SECURITY.md) got its timeline (acknowledged in 7
days, fixed or explained in 30), which is the part Security-Policy scored 9 without.

**The ceiling, computed with Scorecard's weights on 30/09/2026: about 7.7.** The 6.9 is 625 points
over 90 of weight. SAST at 10 adds 50, Security-Policy at 10 adds 5, and a passing OpenSSF Best
Practices badge would add 12.5. What is left measures a TEAM: a second reviewer (Code-Review, and
Branch-Protection, whose next tier needs one before anything else counts) and more than one
organization (Contributors). One person cannot have those, and faking them is the theatre the
table above refuses.

**Vulnerabilities dropped from 10 to 0 on 30/09/2026 with no commit of mine**, and that is the
check that taught the most. Scorecard's osv scan found 14 advisories (one critical) published
against `pyjwt` 2.13.0 and `urllib3` 2.7.0, both transitive in `pkgs/basic-memory/uv.lock`, and a
`uv lock --upgrade-package` of those two brought it back to 10 and the total to 7.6. What it
exposed is that nothing of the repo's OWN watched the lockfiles: Dependabot covers the actions
only, and Scorecard reports a score, it does not alert. So the canary's `advisories` job runs
`osv-scanner scan source -r .` every Monday, from the nixpkgs of this lock (`--inputs-from .`),
and a red run reaches the phone like the other jobs. MEASURED: it exits 0 on the fixed tree, and
1 on the old `uv.lock` (15 vulnerabilities, 1 critical). An advisory that cannot be fixed yet goes
in an `osv-scanner.toml` `[[IgnoredVulns]]` with a `reason` and an `ignoreUntil`, which is rule 22
built into the tool.

So the number to watch is the TREND, not the absolute. A drop means something that was paid for
stopped being true, like a new workflow with a tag instead of a hash, and that is worth a look.
