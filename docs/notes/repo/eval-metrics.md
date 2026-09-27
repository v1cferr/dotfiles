# eval-metrics: what evaluating the config costs

`pkgs/eval-metrics.nix`, run by the gate workflow right after `nix flake check`, and by hand with
`nix run .#eval-metrics`. It evaluates every host in `nixosConfigurations`, writes a table into the
run's summary, and raises a WARNING annotation for any number over
[`ci/eval-budget.json`](../../../ci/eval-budget.json).

## Why it exists

The gate answers "does it evaluate and build", which is green or red and nothing in between. What
it never answered is how much heavier the config gets, and that is the failure that sneaks up on a
repo meant to last until 2032: a `follows` dropped from a new input pulls a third nixpkgs, a module
imports a whole package set for one attribute, and every commit is still green. The run just gets
slower and the evaluation eats more memory, a few percent at a time, until one day the runner OOMs.
The hoisted `pkgsUnstable` in `flake.nix` exists to dodge exactly that class, and nothing measured
whether the next one slips in.

## What it measures, and which numbers get a budget

| Metric | Source | Budgeted |
| --- | --- | --- |
| `derivations` | the `.drv` files in the closure of the host's toplevel | yes |
| `functionCalls` | `nrFunctionCalls` from the evaluator's own stats (`NIX_SHOW_STATS`) | yes |
| `heapBytes` | `gc.totalBytes`, the bytes the evaluation ALLOCATED | yes |
| `cpuSeconds` | `cpuTime` | no |
| lock nodes | `flake.lock`, for the whole flake | yes |

**Only what does not depend on the machine gets a budget.** The same commit gives the same count on
the runner and here: three runs on 27/09/2026 differed by 49 function calls in 13.8 million and by
25 KB in 2.49 GB. `cpuSeconds` is on the table for reading and never judged, since a busy runner
would turn it into noise.

**It measures EVALUATION, never the build.** A closure size needs the build, and the build stays
off the runner (see "`system.build.toplevel` in the CI" in [ideas](../../ideas.md)). The build side
is already covered locally: `nh os switch` prints the package diff of every `rebuild`.

**The eval cache is off** for the measurement (`--option eval-cache false`), or it would answer
from the gate's own run a step earlier and measure nothing.

## The budget, and why a warning and not a failure

Set on 27/09/2026 at about 20% over what was measured that day:

| Metric | Measured | Budget |
| --- | ---: | ---: |
| lock nodes | 24 | 30 |
| derivations | 20,432 | 26,000 |
| functionCalls | 13,845,642 | 16,500,000 |
| heapBytes | 2,486,458,048 | 3,000,000,000 |

Crossing it is a QUESTION, not a bug: a new host service can be worth 10% more derivations. So the
run stays green and carries the warning, and the answer is a commit, either the fix or a raised
number in `ci/eval-budget.json` whose message says why. That commit is the point: the history then
records every time the config got heavier on purpose.

A new host without an entry is reported and warned about, never skipped in silence.
MEASURED on the warning path: with the budgets lowered by hand, both warnings came out as
`::warning::` annotations and the exit stayed 0.
