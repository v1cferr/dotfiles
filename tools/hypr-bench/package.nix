# hypr-bench: A/B runs of the desktop's blur and animations, toggled only at runtime and always
# restored; never installed, run with `nix run .#hypr-bench`: docs/notes/desktop/performance.md
{
  runCommand,
  makeWrapper,
  python3,
  vulkan-tools,
}:

runCommand "hypr-bench"
  {
    nativeBuildInputs = [
      makeWrapper
      python3.pkgs.flake8
    ];
    meta.mainProgram = "hypr-bench";
  }
  ''
    mkdir -p $out/lib/hypr-bench
    cp ${./bench.py} $out/lib/hypr-bench/bench.py
    cp ${./metrics.py} $out/lib/hypr-bench/metrics.py
    cp ${./report.py} $out/lib/hypr-bench/report.py
    cp ${./safety.py} $out/lib/hypr-bench/safety.py
    cp ${./test_report.py} test_report.py
    # E501 off as in repo-stats (the repo wraps at 100, not 79); the build is the lint and the tests.
    flake8 --extend-ignore E501 $out/lib/hypr-bench test_report.py
    PYTHONPATH=$out/lib/hypr-bench ${python3}/bin/python3 -m unittest -q test_report
    # hyprctl and qs stay the session's own (the running compositor's version); vkcube is the
    # fullscreen workload's client, only on this wrapper's PATH.
    makeWrapper ${python3}/bin/python3 $out/bin/hypr-bench \
      --add-flags "-s $out/lib/hypr-bench/bench.py" \
      --set HYPR_BENCH_SELF $out/bin/hypr-bench \
      --suffix PATH : ${vulkan-tools}/bin
  ''
