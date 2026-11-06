# wow-addons-bump: every add-on in sources.json to its latest stable WoW Forever release.
# Why one bump for many add-ons and how each source is asked: docs/notes/apps/wow-addons.md
{
  writeShellApplication,
  coreutils,
  curl,
  jq,
}:

writeShellApplication {
  name = "wow-addons-bump";
  runtimeInputs = [
    coreutils # `sort -V`, for a tag line's highest version
    curl
    jq
  ];
  text = builtins.readFile ./bump.sh; # bash in its own file = shellcheck at build time
  meta.mainProgram = "wow-addons-bump";
}
