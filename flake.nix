{
  description = "My declarative system: NixOS (nixos-kingston) + home-manager, unified";

  inputs = {
    # SYSTEM BASE: the STABLE channel (a release, like Debian/Ubuntu, ~6 months).
    # It is where most packages come from: predictable, no surprises.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # BLEEDING EDGE on demand: the unstable channel (rolling, like Arch). It is NOT
    # the base, it only feeds the `unstable.*` overlay for hand-picked packages.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      # The release branch MATCHES the stable nixpkgs (it avoids option mismatches).
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative partitioning, kept for future bare-metal hosts.
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Encrypted secrets versioned in the repo (passwords, tokens...). The age master
    # key lives OUTSIDE git and is the only thing to carry over on a cutover.
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Zen: not in nixpkgs. It follows the UNSTABLE base, the only `follows` here that does, because
    # upstream started needing ffmpeg_9 and 26.05 stops at 7. The follows: docs/notes/repo/flake.md
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs.home-manager.follows = "home-manager"; # dedup: keeps home-manager_2 out of the lock
    };

    # duo-streak-daemon: the app lives in ITS OWN repo; here it is only DEPLOY, pinned in the lock.
    # flake = false, since it is a plain code repo exposing no Nix outputs.
    duo-streak-daemon = {
      # PRIVATE, so git+ssh: it reuses the SSH key (no token in sops). `update` runs as the USER, who
      # has the key, and the root rebuild reuses the already-pinned store path.
      url = "git+ssh://git@github.com/v1cferr/duo-streak-daemon.git";
      flake = false;
    };

    # A GRUB theme where each OS/generation is a Minecraft "world" with its own icon. The author's
    # OTHER theme was passed over: there an entry is just a button, with no icon per OS.
    minegrub-world-sel-theme = {
      url = "github:Lxtharia/minegrub-world-sel-theme";
      inputs.nixpkgs.follows = "nixpkgs"; # dedup: does not pull a 2nd nixpkgs into the lock
    };

    # Quickshell: a shell/bar in QML, not in nixpkgs. The QML lives in the repo and hot-reloads;
    # see docs/notes/desktop/quickshell.md
    quickshell = {
      url = "git+https://git.outfoxxed.me/quickshell/quickshell";
      inputs.nixpkgs.follows = "nixpkgs"; # dedup
    };

    # Claude Desktop: not in nixpkgs. This flake repackages the OFFICIAL .deb (the nixpkgs pattern
    # for a vendored binary). The 2 alternatives that were passed over: docs/notes/repo/flake.md
    claude-desktop = {
      url = "github:aaddrick/claude-desktop-debian";
      inputs.nixpkgs.follows = "nixpkgs"; # dedup: only affects the lock (the overlay uses the pkgs FROM HERE)
    };

    # git-hooks.nix: it makes the lint catch things BEFORE the commit, not after the push. The HOOKS
    # are in `checks` below and the installer shellHook is in devShells.
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs"; # dedup: statix/deadnix/nixfmt come from the SAME base
    };

    # Chrome DEV/BETA: nixpkgs only packages stable, and this nix-community flake keeps -dev fresh.
    browser-previews = {
      url = "github:nix-community/browser-previews";
      inputs.nixpkgs.follows = "nixpkgs"; # dedup (its own derivation, no dep on unstable)
    };

    # VS Code from the OFFICIAL tarball at a FIXED, VERSIONED url: `/latest/` is a POINTER and broke
    # the eval on every release. What bumps it is vscode-bump, on `update`: docs/notes/repo/flake.md
    vscode-tarball = {
      url = "tarball+https://update.code.visualstudio.com/1.134.0/linux-x64/stable";
      flake = false;
    };
  };

  outputs =
    {
      self, # used in devShells (it reads the shellHook from checks.pre-commit)
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      disko,
      sops-nix,
      ...
    }@inputs:
    let
      system = "x86_64-linux";

      # ONE unstable instance, hoisted OUT of the overlay on purpose: inside it the import would run
      # per pkgs instance AND per splice (pkgsi686Linux), which is the OOM everyone hits.
      pkgsUnstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };

      # It exposes `pkgs.unstable.<pkg>` while everything else stays on the stable base, which is what
      # gives the choice PER PACKAGE.
      overlayUnstable = _: _: { unstable = pkgsUnstable; };

      # Spotify: `--no-zygote` baked into the PACKAGE (not the autostart), or CEF dies of SIGTRAP in
      # 270ms with no window. REMOVE when it opens without it: docs/notes/repo/flake.md
      overlaySpotifyNoZygote = _: prev: {
        unstable = prev.unstable // {
          spotify = prev.unstable.spotify.overrideAttrs (old: {
            postFixup = (old.postFixup or "") + ''
              wrapProgram $out/bin/spotify --add-flags "--no-zygote"
            '';
          });
        };
      };

      # It swaps only the SRC, keeping unstable's RECIPE, because generic.nix is version-gated and the
      # 26.05 one is 12 versions behind. Why readFile and sourceRoot: docs/notes/repo/flake.md
      overlayVscodeTarball = _: prev: {
        unstable = prev.unstable // {
          vscode = prev.unstable.vscode.overrideAttrs (_: {
            inherit
              (builtins.fromJSON (builtins.readFile "${inputs.vscode-tarball}/resources/app/package.json"))
              version
              ;
            src = inputs.vscode-tarball;
            sourceRoot = "source";
          });
        };
      };

      # btop with Intel Xe: TEMPORARY. nixpkgs' btop has GPU on, but its Intel backend is i915-ONLY and
      # the B580 is xe. REMOVE when PR #1457 lands in the channel: docs/notes/repo/flake.md
      overlayBtopXe = _: prev: {
        btop = prev.btop.overrideAttrs (old: {
          version = "1.4.7-unstable-2026-07-20";
          src = prev.fetchFromGitHub {
            owner = "deveworld";
            repo = "btop";
            rev = "76530c80dd6184ccb72d7048c2589afdc4bdee52"; # feature/xe-gpu-support, head of PR #1457
            hash = "sha256-zBzr2NmekUvK8Hae5N/8qu9OdfGK5+Kzu7maZOVK/sY=";
          };
          doInstallCheck = false;
          meta = old.meta // {
            changelog = "https://github.com/aristocratos/btop/pull/1457";
          };
        });
      };

      # LOCAL packages in ./pkgs, exposed as `pkgs.<name>`; callPackage injects the deps. Most are
      # outside nixpkgs, `codex` REPLACES the one there (the note says why).
      overlayLocalPkgs = final: _: {
        claude-code-discord-status = final.callPackage ./pkgs/claude-code-discord-status.nix { };
        azure-mcp = final.callPackage ./pkgs/azure-mcp.nix { }; # Azure MCP Server (`azmcp`), only in claude-fai
        nxbender = final.callPackage ./pkgs/nxbender.nix { }; # FOSS client for the SonicWall VPN (FAI)
        vscode-bump = final.callPackage ./pkgs/vscode-bump.nix { }; # bumps vscode-tarball to the latest stable
        codex = final.callPackage ./pkgs/codex.nix { }; # OpenAI's CLI, the OFFICIAL release binary
        codex-bump = final.callPackage ./pkgs/codex-bump.nix { }; # version+hash of codex.nix
        curseforge = final.callPackage ./pkgs/curseforge.nix { }; # official modpack AppImage (unfree)
        curseforge-bump = final.callPackage ./pkgs/curseforge-bump.nix { }; # version+hash of curseforge.nix
        curseforge-fix-perms = final.callPackage ./pkgs/curseforge-fix-perms.nix { }; # +x on what the app unpacks
        razer-dpi = final.callPackage ./pkgs/razer-dpi.nix { }; # the Razer mouse's live DPI, over hidraw
        docs-links = final.callPackage ./pkgs/docs-links.nix { }; # it fails when a docs/ pointer breaks
        dead-config = final.callPackage ./pkgs/dead-config.nix { }; # it fails on declared-and-unused
        router-ssot = final.callPackage ./pkgs/router-ssot.nix { }; # it fails when the router's mirror diverges
      };

      # Claude Desktop: it forces the secret backend, since Electron does not recognize "Hyprland" and
      # falls back to plaintext, so the login is asked EVERY time. Only the fixpoint one is wrapped.
      overlayClaudeKeyring = _: prev: {
        claude-desktop = prev.claude-desktop.overrideAttrs (old: {
          postInstall = (old.postInstall or "") + ''
            wrapProgram $out/bin/claude-desktop --add-flags "--password-store=gnome-libsecret"
          '';
        });
      };

      # A host = the COMMON modules plus its own FOLDER. hostname/disks/kernel/monitors/stateVersion
      # and the my.services panel belong to the HOST; system/ only declares the options.
      mkHost =
        hostModule:
        nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; };
          modules = [
            # `hostPlatform` and not nixosSystem's `system`, which nixpkgs itself calls legacy and zeroes:
            # its default is builtins.currentSystem, which is IMPURE. As a module option it is hermetic.
            { nixpkgs.hostPlatform = system; }

            # unstable.* plus ./pkgs plus claude-desktop, as an OVERLAY so it builds against THIS base and
            # adds no 3rd nixpkgs. The keyring one comes AFTER, since it re-wraps their package.
            {
              nixpkgs.overlays = [
                overlayUnstable
                overlayVscodeTarball # AFTER overlayUnstable: it patches that `unstable.vscode`
                overlaySpotifyNoZygote # same: bakes in the flag without which Spotify does not open
                overlayBtopXe # temporary: Intel Xe GPU (Arc B580) until PR #1457 merges
                overlayLocalPkgs
                inputs.claude-desktop.overlays.default
                overlayClaudeKeyring
              ];
            }
            sops-nix.nixosModules.sops
            disko.nixosModules.disko # inert on hosts with no disko.devices
            ./system
            hostModule

            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true; # uses the system nixpkgs (+ overlay)
              home-manager.useUserPackages = true; # installs into the user profile
              home-manager.extraSpecialArgs = { inherit inputs; };
              home-manager.users.v1cferr = import ./home;
            }
          ];
        };
    in
    {
      nixosConfigurations = {
        # The ONLY host: an NVMe Kingston KC3000 on an ASUS EX-B560M-V5, btrfs through disko.
        #   sudo nixos-rebuild switch --flake .#nixos-kingston
        nixos-kingston = mkHost ./hosts/nixos-kingston;
      };

      # What THIS repo packages, exposed piece by piece so `nix build .#nxbender` works in isolation.
      # `pkgs` comes from the HOST, so the check cannot diverge from what the machine gets (rule 14).
      packages.${system} =
        let
          pkgs = self.nixosConfigurations.nixos-kingston.pkgs;
        in
        {
          inherit (pkgs)
            claude-code-discord-status # ./pkgs: the Rich Presence daemon
            nxbender # ./pkgs: the SonicWall VPN client (3 patches on top of upstream)
            claude-desktop # someone else's flake + the keyring wrapper from here
            vscode-bump # ./pkgs: the build IS the script's shellcheck (rule 7)
            codex # ./pkgs: the official binary, so the check proves the fetch and the wrapper
            codex-bump # ./pkgs: same shellcheck at build time
            curseforge-bump # ./pkgs: same, shellcheck at build time
            curseforge-fix-perms # ./pkgs: same
            docs-links # ./pkgs: the build IS the script's flake8; the CHECK below runs it
            dead-config # ./pkgs: same, and the CHECK below runs it too
            router-ssot # ./pkgs: same, and the CHECK below runs it too
            curseforge # ./pkgs: the official AppImage (outside the CHECK below, the why is there)
            btop # nixpkgs + the src from PR #1457 (Intel Xe GPU): here so the check COMPILES the fork
            ;
          inherit (pkgs.unstable) vscode; # the unstable recipe with the SRC from the official tarball
        };

      # `nix fmt`, so the standard is verifiable OUTSIDE the editor. `nixfmt-tree` and not bare nixfmt,
      # which breaks with no argument AND walks into ./result: docs/notes/repo/flake.md
      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-tree;

      # THE QUALITY GATE: ONE definition, THREE consumers (flake check, the pre-commit hook, the CI).
      # It used to be two parallel definitions of the same rule, which is rule 14's silent drift.
      checks.${system} = {
        pre-commit = inputs.git-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            # `nixfmt` and NOT `nixfmt-rfc-style`: that distinction EXPIRED on 18/08/2026. Both hooks
            # now resolve to the same nixfmt-1.4.0 and entry; only the old alias warns on eval.
            nixfmt.enable = true;
            # Both read the repo config (./statix.toml) because they run with cwd at the root.
            statix.enable = true;
            deadnix.enable = true;
            # It covers ./scripts because owfetch.sh runs in ash on OpenWrt, so no derivation wraps it: it
            # would otherwise be the only .sh here running on SOMEONE ELSE'S machine with no check.
            shellcheck.enable = true;
            # The three repo checkers run HERE too, not only in the gate: the whole reason
            # git-hooks.nix is an input is catching it before the commit instead of after the
            # push. pass_filenames = false because all three audit the TREE, not a file list.
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
                nixpkgs.legacyPackages.${system}.git
              ];
            }
            ''
              cp -r ${./.} src && chmod -R +w src && cd src
              # The flake source has no .git, and both checkers walk `git ls-files` on purpose
              # (they should see what the repo SHIPS). A throwaway repo gives them that list.
              git init -q && git add -A
              docs-links
              dead-config
              router-ssot
              touch $out
            '';

        # It BUILDS what the repo packages, which `nix flake check` does NOT: it only EVALUATES a host.
        # What is fragile here is packaging, and that breaks at build. curseforge is out: the notes.
        packages = nixpkgs.legacyPackages.${system}.linkFarm "checks-repo-packages" (
          nixpkgs.lib.mapAttrsToList (name: path: { inherit name path; }) (
            removeAttrs self.packages.${system} [ "curseforge" ]
          )
        );
      };

      # The devShell exists to INSTALL .git/hooks/pre-commit (git-hooks' shellHook); with direnv, a cd
      # into the repo does it in any fresh clone. enabledPackages pins the linters to the hooks'.
      devShells.${system}.default =
        let
          pkgs = nixpkgs.legacyPackages.${system};
          inherit (self.checks.${system}.pre-commit) shellHook enabledPackages;
        in
        # mkShellNoCC and NOT mkShell: nothing here compiles C, and mkShell's stdenv makes direnv dump a
        # paragraph of +CC/+LD/+NIX_CFLAGS exports on every cd into the repo.
        pkgs.mkShellNoCC {
          inherit shellHook;
          # sops: `scripts/sync-secrets.sh` needs it and it is NOT in any profile, so without
          # this the script died at its first `sops set`, mid-run, on 18/08/2026.
          buildInputs = enabledPackages ++ [
            pkgs.nixd
            pkgs.sops
          ];
        };
    };
}
