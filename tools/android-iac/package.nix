# android-iac: reads an Android phone over ADB, read-only, and diffs it against its host's
# declaration; the build is the lint, the types and the tests: docs/notes/hardware/android-iac.md
{
  lib,
  runCommand,
  writeText,
  makeWrapper,
  python3,
  android-tools,
  device,
}:

let
  # The host's data, as the JSON the tool reads (rule 11: hosts/<phone>/default.nix owns it).
  spec = writeText "android-iac-${device.name}.json" (builtins.toJSON device);
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.fileFilter (f: f.hasExt "py" || f.hasExt "txt") ./.;
  };
in
runCommand "android-iac"
  {
    nativeBuildInputs = [
      makeWrapper
      python3.pkgs.flake8
      python3.pkgs.mypy
    ];
    meta.mainProgram = "android-iac";
  }
  ''
    cp -r ${src} src && chmod -R +w src && cd src
    # E501 off as in hypr-bench (the repo wraps at 100, not 79).
    flake8 --extend-ignore E501 .
    MYPYPATH=.:tests mypy --strict --no-error-summary --cache-dir=/dev/null *.py tests/*.py
    ANDROID_IAC_SPEC=${spec} PYTHONPATH=.:tests HOME=$TMPDIR ${python3}/bin/python3 -m unittest discover -s tests -q
    mkdir -p $out/lib/android-iac
    cp *.py $out/lib/android-iac/
    # The user's adb wins when present, so one adb server version talks to the phone.
    makeWrapper ${python3}/bin/python3 $out/bin/android-iac \
      --add-flags "-s $out/lib/android-iac/cli.py" \
      --set ANDROID_IAC_SPEC ${spec} \
      --suffix PATH : ${android-tools}/bin
  ''
