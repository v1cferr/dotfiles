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
| SAST | CodeQL has no Nix analyser; the linters in `nix flake check` are that layer |
| Fuzzing, Packaging, Signed-Releases, CII-Best-Practices | a machine config, not a released artifact |
| Contributors | a personal repo |

So the number to watch is the TREND, not the absolute. A drop means something that was paid for
stopped being true, like a new workflow with a tag instead of a hash, and that is worth a look.
