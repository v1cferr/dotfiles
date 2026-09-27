# eval-metrics: what evaluating each host COSTS, against the budget in ci/eval-budget.json. It warns
# instead of failing, since a budget is a question to answer: docs/notes/repo/eval-metrics.md
{ writers }:

writers.writePython3Bin "eval-metrics"
  {
    flakeIgnore = [ "E501" ]; # the repo's line length is 100, not flake8's 79
  }
  ''
    """Evaluate every host, measure the cost, and compare it with the declared budget."""
    import json
    import os
    import subprocess
    import sys
    import tempfile

    BUDGET = "ci/eval-budget.json"

    # Only numbers that do not depend on the MACHINE get a budget: the same commit gives the same
    # count on the runner and here. cpuTime is reported, never judged.
    BUDGETED = ("derivations", "functionCalls", "heapBytes")


    def nix(args, extra, **kw):
        return subprocess.run(["nix", *args, *extra], check=True, text=True, capture_output=True, **kw)


    def measure(host, extra):
        """Instantiate the host's toplevel with the evaluator's own stats written to a file."""
        attr = f".#nixosConfigurations.{host}.config.system.build.toplevel.drvPath"
        with tempfile.NamedTemporaryFile(suffix=".json") as stats:
            env = dict(os.environ, NIX_SHOW_STATS="1", NIX_SHOW_STATS_PATH=stats.name)
            # The eval cache would answer from the gate's own run and measure nothing.
            drv = nix(["eval", "--raw", "--option", "eval-cache", "false", attr], extra, env=env).stdout
            data = json.load(open(stats.name))
        closure = subprocess.run(["nix-store", "-qR", drv], check=True, text=True, capture_output=True)
        return {
            "derivations": sum(1 for p in closure.stdout.split() if p.endswith(".drv")),
            "functionCalls": data["nrFunctionCalls"],
            "heapBytes": data["gc"]["totalBytes"],
            "cpuSeconds": round(data["cpuTime"], 1),
        }


    def main():
        extra = sys.argv[1:]  # e.g. the CI's --override-input for the private input
        budget = json.load(open(BUDGET))
        hosts = json.loads(nix(["eval", "--json", ".#nixosConfigurations", "--apply", "builtins.attrNames"], extra).stdout)
        lock_nodes = len(json.load(open("flake.lock"))["nodes"])

        rows, warnings = [], []
        if lock_nodes > budget["lockNodes"]:
            warnings.append(f"flake.lock has {lock_nodes} nodes, budget {budget['lockNodes']}")
        for host in hosts:
            got = measure(host, extra)
            limits = budget["hosts"].get(host)
            if limits is None:
                warnings.append(f"{host} has no budget in {BUDGET}")
                limits = {}
            for key in BUDGETED:
                if key in limits and got[key] > limits[key]:
                    warnings.append(f"{host}: {key} {got[key]:,} over the budget of {limits[key]:,}")
            for key, value in got.items():
                cap = f"{limits[key]:,}" if key in limits else ""
                rows.append(f"| {host} | {key} | {value:,} | {cap} |")

        table = "\n".join([
            f"### Evaluation cost ({lock_nodes} lock nodes, budget {budget['lockNodes']})",
            "",
            "| Host | Metric | Value | Budget |",
            "| --- | --- | ---: | ---: |",
            *rows,
            "",
        ])
        print(table)
        if os.environ.get("GITHUB_STEP_SUMMARY"):
            with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as fh:
                fh.write(table + "\n")
        for w in warnings:
            # An annotation on the run in the CI, a plain line anywhere else.
            print(f"::warning::{w}" if os.environ.get("GITHUB_ACTIONS") else f"warning: {w}")


    main()
  ''
