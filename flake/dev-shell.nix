# The devShell: it installs the git hooks on a cd (direnv) and pins the linters to the hooks'
# versions, plus the site's node and pnpm. Why mkShellNoCC: docs/notes/repo/flake.md
{
  self,
  inputs,
  system,
}:

let
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  # It exists to INSTALL .git/hooks/pre-commit (git-hooks' shellHook): with direnv, a cd into the
  # repo does it in any fresh clone. enabledPackages pins the linters to the hooks'.
  inherit (self.checks.${system}.pre-commit) shellHook enabledPackages;
in
# mkShellNoCC and NOT mkShell: nothing here compiles C, and mkShell's stdenv makes direnv dump a
# paragraph of +CC/+LD/+NIX_CFLAGS exports on every cd into the repo.
pkgs.mkShellNoCC {
  inherit shellHook;
  # sops: `modules/nixos/core/sync-secrets.sh` needs it and it is NOT in any profile, so without
  # this the script died at its first `sops set`, mid-run, on 18/08/2026.
  buildInputs = enabledPackages ++ [
    pkgs.nixd
    pkgs.sops
    # `pnpm --dir tools/docs-site dev` with live reload, on the SAME node and pnpm the site
    # derivation builds with: the preview and the build cannot drift (rule 11).
    self.packages.${system}.docs-site.nodejs
    self.packages.${system}.docs-site.pnpm
  ];
}
