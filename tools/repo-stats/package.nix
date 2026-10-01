# repo-stats: the README's numbers, counted at BUILD from the flake source and drawn as SVG, so the
# same commit always shows the same stats: docs/notes/repo/readme.md
{
  runCommand,
  writers,
  scc,
  src,
  facts,
}:

let
  render = writers.writePython3 "render-stats" {
    flakeIgnore = [ "E501" ]; # the repo's line length is 100, not flake8's 79
  } (builtins.readFile ./render.py);
in
runCommand "repo-stats"
  {
    nativeBuildInputs = [ scc ];
    factsJson = builtins.toJSON facts;
    passAsFile = [ "factsJson" ];
  }
  ''
    mkdir -p $out
    scc --format json --no-cocomo --no-complexity ${src} > scc.json
    ${render} scc.json "$factsJsonPath" ${src} $out
  ''
