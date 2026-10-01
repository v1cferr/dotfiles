# THE QUALITY GATE: the pre-commit hooks, the repo audit and the packages build, defined ONCE for
# three consumers (flake check, the hook, the CI). Why each hook: docs/notes/repo/flake.md
{
  self,
  inputs,
  system,
}:

let
  inherit (inputs) nixpkgs;
in
# It used to be two parallel definitions of the same rule, which is rule 14's silent drift.
{
  pre-commit = inputs.git-hooks.lib.${system}.run {
    src = ../.;
    hooks = {
      # `nixfmt` and NOT `nixfmt-rfc-style`: that distinction EXPIRED on 18/08/2026. Both hooks
      # now resolve to the same nixfmt-1.4.0 and entry; only the old alias warns on eval.
      nixfmt.enable = true;
      # statix reads the repo's policy from .config/, where every tool config lives (decision 0009).
      statix = {
        enable = true;
        settings.config = ".config/statix.toml";
      };
      deadnix.enable = true;
      # It covers hosts/cudy-wr3000/owfetch.sh, which runs in ash on OpenWrt with no derivation
      # around it: otherwise the one .sh running on SOMEONE ELSE'S machine would go unchecked.
      shellcheck.enable = true;
      # The ENTRY is overridden to read .config/markdownlint.jsonc, the same file the editor reads:
      # the hook's own `settings.configuration` would be a 2nd owner of the ruleset (rule 14).
      markdownlint = {
        enable = true;
        entry = "${
          nixpkgs.legacyPackages.${system}.markdownlint-cli
        }/bin/markdownlint --config .config/markdownlint.jsonc";
      };
      # It fails on a `secrets/*.yaml` that is NOT encrypted, the one accident rule 12 cannot
      # survive. `files` is NARROWED: the hook's default `^secrets` fails on the plain INDEX.
      pre-commit-hook-ensure-sops = {
        enable = true;
        files = "^secrets/.*\\.yaml$";
        # sops' own config lives beside the vault now: plain recipients, never a secret.
        excludes = [ "^secrets/\\.sops\\.yaml$" ];
      };
      # The workflow gets what the .nix tree already had: actionlint for the YAML and the
      # expressions, zizmor for the security audit. Both are scoped to .github/workflows.
      actionlint.enable = true;
      zizmor.enable = true;
      # A credential in the STAGED diff, the class that leaked the rpcd_token on 08/08. The
      # history half runs in the canary: docs/notes/repo/github-settings.md
      gitleaks =
        let
          inherit (nixpkgs.legacyPackages.${system}) gitleaks;
        in
        {
          enable = true;
          name = "gitleaks";
          package = gitleaks;
          entry = "${gitleaks}/bin/gitleaks git --pre-commit --staged --no-banner --redact --config .config/gitleaks.toml --gitleaks-ignore-path .config";
          language = "system";
          pass_filenames = false;
        };
      # The 8 Hyprland `.lua`, type-checked by the LSP itself, reading THE SAME .config/luarc.json
      # the editor reads: that file is plain JSON, so `fromJSON` can (markdownlint's cannot).
      lua-ls = {
        enable = true;
        settings.configuration = builtins.fromJSON (builtins.readFile ../.config/luarc.json);
      };
      # The 27 `.qml`: PARSE only. The rest of qmllint does not understand Quickshell's
      # types and produced 2267 findings, almost all false: docs/notes/desktop/quickshell.md
      qml-syntax = {
        enable = true;
        name = "qml-syntax";
        entry = "${self.packages.${system}.qml-syntax}/bin/qml-syntax";
        language = "system";
        files = "\\.qml$";
      };
      # The 14 `.json`/`.jsonc`/`.toml`. Nix parses two of them (`luarc.json` and the
      # secrets index) and fails at eval; the rest are read by a TOOL, which answers a
      # broken file by falling back to its defaults and saying nothing.
      data-syntax = {
        enable = true;
        name = "data-syntax";
        entry = "${self.packages.${system}.data-syntax}/bin/data-syntax";
        language = "system";
        files = "\\.(json|jsonc|toml)$";
      };
      # The two .py in the tree: `modules/nixos/network/router-sync.py` and kitty's smart-paste kitten.
      # `check` with no --fix on purpose: a linter that rewrites Python is not a formatter.
      ruff = {
        enable = true;
        entry = "${nixpkgs.legacyPackages.${system}.ruff}/bin/ruff check";
      };
      # EXTERNAL links, `.md` only. It needs NETWORK, so it can NEVER be part of the gate
      # (the build sandbox has none) and sits at the `manual` stage, run weekly by the CI.
      lychee = {
        enable = true;
        stages = [ "manual" ];
        files = "\\.md$";
        settings.flags = "--max-concurrency 6 --no-progress --scheme https --scheme http";
      };
      # Rule 17's commit GRAMMAR, at the commit-msg stage. It is the only hook here that the
      # gate cannot run: `pre-commit run --all-files` has no message to look at.
      convco.enable = true;
      # Rule 17's three BANS, in the TREE: no em dash, no emoji, and a quoted literal is the
      # exception. pass_filenames = false because it audits the tree, like the three below.
      prose-style = {
        enable = true;
        name = "prose-style";
        entry = "${self.packages.${system}.prose-style}/bin/prose-style";
        language = "system";
        pass_filenames = false;
      };
      # The SAME script over the MESSAGE, where it also refuses a Co-Authored-By trailer.
      # pre-commit appends the message file, which is the argument the mode needs.
      prose-style-commit-msg = {
        enable = true;
        name = "prose-style (commit message)";
        entry = "${self.packages.${system}.prose-style}/bin/prose-style --commit-msg";
        language = "system";
        stages = [ "commit-msg" ];
      };
      # The three repo checkers run HERE too, not only in the gate: the whole reason
      # git-hooks.nix is an input is catching it before the commit instead of after the
      # push. pass_filenames = false because all three audit the TREE, not a file list.
      # The SITE's own validation, which is what keeps every page reachable (rule 20). At
      # the COMMIT since the Fumadocs migration: it stopped being a 7.12s build of the whole
      # site and became a read of docs/ plus one file, so the cheap unit is the right one.
      docs-site = {
        enable = true;
        name = "docs-site";
        entry = "${self.packages.${system}.docs-site-check}/bin/docs-site-check";
        language = "system";
        pass_filenames = false;
      };
      # The JS half of the lint, over the site's own TypeScript. The BINARY comes from
      # nixpkgs like every other linter here, so the lock pins it (rule 13); the rules live
      # in `tools/docs-site/.oxlintrc.json`, which is the file the editor reads too.
      oxlint = {
        enable = true;
        name = "oxlint";
        entry = "${nixpkgs.legacyPackages.${system}.oxlint}/bin/oxlint";
        language = "system";
        files = "^tools/docs-site/.*\\.(ts|tsx|mjs)$";
      };
      docs-links = {
        enable = true;
        name = "docs-links";
        entry = "${self.packages.${system}.docs-links}/bin/docs-links";
        language = "system";
        pass_filenames = false;
      };
      dead-config = {
        enable = true;
        name = "dead-config";
        entry = "${self.packages.${system}.dead-config}/bin/dead-config";
        language = "system";
        pass_filenames = false;
      };
      router-ssot = {
        enable = true;
        name = "router-ssot";
        entry = "${self.packages.${system}.router-ssot}/bin/router-ssot";
        language = "system";
        pass_filenames = false;
      };
      rules-index = {
        enable = true;
        name = "rules-index";
        entry = "${self.packages.${system}.rules-index}/bin/rules-index";
        language = "system";
        pass_filenames = false;
      };
    };
  };

  # Rule 16 says dead config leaves and a stale note is a bug, rule 2 made the pointer the ONLY
  # path from a module to its reasoning, and rule 11 says a value has ONE owner even when the
  # second copy lives on a device Nix cannot reach. All three were memory alone until here.
  repo-audit =
    nixpkgs.legacyPackages.${system}.runCommand "check-repo-audit"
      {
        nativeBuildInputs = [
          self.packages.${system}.docs-links
          self.packages.${system}.dead-config
          self.packages.${system}.router-ssot
          self.packages.${system}.rules-index
          nixpkgs.legacyPackages.${system}.git
        ];
      }
      ''
        cp -r ${../.} src && chmod -R +w src && cd src
        # The flake source has no .git, and both checkers walk `git ls-files` on purpose
        # (they should see what the repo SHIPS). A throwaway repo gives them that list.
        git init -q && git add -A
        docs-links
        dead-config
        router-ssot
        rules-index
        touch $out
      '';

  # It BUILDS what the repo packages, which `nix flake check` does NOT: it only EVALUATES a host.
  # What is fragile here is packaging, and that breaks at build. curseforge is out: the notes.
  packages = nixpkgs.legacyPackages.${system}.linkFarm "checks-repo-packages" (
    nixpkgs.lib.mapAttrsToList (name: path: { inherit name path; }) (
      removeAttrs self.packages.${system} [
        "curseforge" # a POINTER url: its hash rots on every release of theirs, the why is above
        "vm-boot" # a whole system closure plus a QEMU run: same reason toplevel stays out
        "disko-vm" # building it means building a 24 GiB image, and it is interactive anyway
      ]
    )
  );
}
