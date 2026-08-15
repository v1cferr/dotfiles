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

    # Zen Browser: NOT in nixpkgs, so this flake follows the upstream releases.
    # "Always the latest version" = bump with `nix flake update zen-browser`.
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager"; # dedup: keeps home-manager_2 out of the lock
    };

    # duo-streak-daemon: the app (Playwright daemon + API + web + Docker) lives in ITS
    # OWN repo. Here it is only DEPLOY: the commit is pinned in flake.lock (bump with
    # `nix flake update duo-streak-daemon`) and docker-compose builds from the store path.
    # flake = false: it is a plain code repo, it exposes no Nix outputs.
    duo-streak-daemon = {
      # PRIVATE repo, so git+ssh (it reuses the SSH key, no token in sops). `nix flake
      # lock`/update runs as the USER (who has the key) and populates the store; the
      # rebuild as root reuses the store path already pinned, with no re-fetch.
      url = "git+ssh://git@github.com/v1cferr/duo-streak-daemon.git";
      flake = false;
    };

    # A GRUB theme in the style of the Minecraft "world selection" screen: each
    # OS/generation becomes a "world" with an icon and a description. It is the one for
    # the NixOS ⇄ Windows 11 dualboot, ACTIVE in system/core/boot.nix. The other theme by
    # the same author (minegrub-theme, the Minecraft main menu) was passed over: an entry
    # becomes a button, with no icon per OS.
    minegrub-world-sel-theme = {
      url = "github:Lxtharia/minegrub-world-sel-theme";
      inputs.nixpkgs.follows = "nixpkgs"; # dedup: does not pull a 2nd nixpkgs into the lock
    };

    # Quickshell: a shell/bar in QML (outfoxxed), NOT in nixpkgs. "Always the latest"
    # means bumping with `nix flake update quickshell`. The QML config lives in the repo
    # (home/desktop/quickshell/) and is linked by mkOutOfStoreSymlink, so it hot-reloads.
    quickshell = {
      url = "git+https://git.outfoxxed.me/quickshell/quickshell";
      inputs.nixpkgs.follows = "nixpkgs"; # dedup
    };

    # Claude Desktop: NOT in nixpkgs (issue #366213 was closed; the channel only has
    # claude-code/claude-monitor). This flake REPACKAGES the OFFICIAL .deb that Anthropic
    # started publishing on 30/06/2026 (Linux beta, its own APT), which is the nixpkgs
    # pattern for a vendored binary (dpkg-deb + autoPatchelfHook), like discord/vscode.
    # Passed over: k3d3/claude-desktop-linux-flake (the pioneer, but it reverse engineered
    # the Windows binary and has been idle since nov/2025) and heytcass/claude-for-linux
    # (extracts from the macOS DMG; 6 stars, 77 issues). Upstream CI bumps version+hash on
    # its own, so "the latest version" = `nix flake update claude-desktop`.
    claude-desktop = {
      url = "github:aaddrick/claude-desktop-debian";
      inputs.nixpkgs.follows = "nixpkgs"; # dedup: only affects the lock (the overlay uses the pkgs FROM HERE)
    };

    # git-hooks.nix: pre-commit managed by Nix. It is what makes the lint catch things
    # BEFORE the commit instead of after the push: without it, `nix flake check` and the CI
    # only fail once the mistake is already in the history. The HOOKS are declared in checks
    # below, and the `shellHook` that installs .git/hooks/pre-commit comes from devShells.
    # (cachix/git-hooks.nix is the current name; the old pre-commit-hooks.nix repo redirects.)
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs"; # dedup: statix/deadnix/nixfmt come from the SAME base
    };

    # Google Chrome DEV/BETA channels: nixpkgs only packages stable. This maintained flake
    # (nix-community) keeps google-chrome-dev fresh; "latest" = bump with
    # `nix flake update browser-previews`. Used in home/packages.nix.
    browser-previews = {
      url = "github:nix-community/browser-previews";
      inputs.nixpkgs.follows = "nixpkgs"; # dedup (its own derivation, no dep on unstable)
    };

    # VS Code from the OFFICIAL stable-channel tarball, at a FIXED version. It exists because
    # nixpkgs does not serve: the bump there is human/bot and runs 3 to 14 days behind, and it
    # sometimes SKIPS a release (1.125 to 1.127, 1.127 to 1.129.1 in jul/26). The cause is
    # structural: the VS Code auto-updater does not run with a read-only store, so the version
    # is literally whatever is in the lock. This is NOT Insiders (the daily test build).
    # `flake = false` because it is a tarball, not a flake.
    #
    # THE NAME: it was called `vscode-latest` until 05/08/2026, and the name turned into a lie
    # the minute the URL was pinned: "latest" promised an automatic tracking that no longer
    # exists. `-tarball` says what it IS (and explains the `flake = false`), without promising
    # a version.
    #
    # A VERSIONED URL and not `/latest/`: this changed on 05/08/2026, and the reason was the CI
    # going RED:
    #   error: mismatch in field 'narHash' of input '.../latest/linux-x64/stable'
    #          lock: sha256-2Fzf... | served: sha256-PLpT...
    # The cause: `/latest/` is a POINTER. 1.132.0 shipped, the pointer moved, and the pinned
    # narHash (which was 1.131.0's) stopped matching. Here it passed because the old tarball was
    # already in the store; on a clean machine (CI, a fresh clone, a reinstall) the flake did not
    # evaluate anymore. In other words: the hole in rule 13 was not a 2032 risk, it broke on
    # every VS Code release.
    #
    # Measured before switching, which is what proves the versioned URL fixes it: `/1.131.0/`
    # returns exactly the `sha256-2Fzf...` that was in the lock, and `/1.132.0/` returns
    # `sha256-PLpT...`, both stable across repeated fetches. A versioned artifact is immutable;
    # a pointer is not.
    #
    # THE PRICE of a fixed URL: `nix flake update` does not bring a new version on its own. Who
    # pays it is `vscode-bump` (pkgs/vscode-bump.nix) since 06/08/2026: it queries the official
    # API, rewrites the number on THIS line and runs `nix flake update vscode-tarball`. It is the
    # first step of the `update`/`upgrade` aliases (home/shell/zsh.nix), so "always on the latest
    # stable" happens at rebuild time, with no manual edit and without breaking rule 13 (the hash
    # is still pinned in the lock; what changed is WHO updates it). Bumping by hand is still
    # possible: edit here + `nix flake update vscode-tarball`.
    vscode-tarball = {
      url = "tarball+https://update.code.visualstudio.com/1.132.0/linux-x64/stable";
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

      # ONE instance of the unstable channel, created OUTSIDE the overlay on purpose. Inside
      # it, the `import` runs once per `pkgs` instance, and an overlay also applies to the
      # SPLICES (`pkgsi686Linux`, which Steam instantiates because of 32-bit): the day someone
      # touches `pkgs.pkgsi686Linux.unstable`, the unstable tree would be imported ANOTHER
      # time. Today it is lazy and costs nothing; hoisting the import is what keeps it that
      # way. It is also what the community associates with evaluation OOM (discourse 1517):
      # the cost shows up once the instances add up.
      pkgsUnstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };

      # Overlay that exposes `pkgs.unstable.<package>` = the unstable channel's version, while
      # the whole rest of the system stays on the stable base. That is what gives the choice
      # per package: `pkgs.foo` (stable) vs `pkgs.unstable.foo` (the latest).
      overlayUnstable = _: _: { unstable = pkgsUnstable; };

      # Spotify: `--no-zygote` baked into the PACKAGE, without which the app does not open. Its
      # CEF aborts with "GPU process isn't usable. Goodbye." and dies of SIGTRAP in ~270ms, with
      # no window and no visible error. `--disable-gpu` and `--no-sandbox` change nothing, only
      # this flag works around it (measured 11/08/2026 on 1.2.92.147; the earlier suspicion,
      # that it was the VERSION, was wrong: 1.2.92 crashes just like 1.2.90).
      #
      # WHY IN THE PACKAGE and not in the `exec` of home/desktop/autostart.nix, which would be
      # the shorter line: Spotify's `.desktop` uses `Exec=spotify`, a BARE name resolved through
      # PATH. A flag only in the autostart would fix boot and leave the MENU crashing, with two
      # places to keep in sync. Wrapping the package, every path that reaches the profile's
      # `spotify` gets the flag (rule 15: a single owner).
      #
      # postFixup and not postInstall: the nixpkgs recipe does its own wrap in installPhase, and
      # fixupPhase runs AFTER, so wrapping earlier would wrap what does not exist yet.
      # `$out/bin/spotify` is a symlink to ../share/spotify/spotify; wrapProgram moves the
      # symlink to bin/.spotify-wrapped (the relative target stays valid, same dir) and puts the
      # wrapper in its place.
      #
      # It patches INSIDE `unstable` (hence after overlayUnstable), for the same reason as
      # overlayVscodeTarball: `unstable` is another import of nixpkgs.
      # REMOVE once Spotify opens again without the flag. Testing that is running `spotify`
      # without it.
      overlaySpotifyNoZygote = _: prev: {
        unstable = prev.unstable // {
          spotify = prev.unstable.spotify.overrideAttrs (old: {
            postFixup = (old.postFixup or "") + ''
              wrapProgram $out/bin/spotify --add-flags "--no-zygote"
            '';
          });
        };
      };

      # Swaps only the vscode SRC for the tarball from the vscode-tarball input, keeping the
      # RECIPE from unstable: the nixpkgs generic.nix has version-gated logic (`versionAtLeast
      # vscodeVersion "1.129.0"`), so patching a fresh recipe is the minimal delta; over the
      # 26.05 recipe (which was 1.119) a 12-version jump would go through branches that do not
      # exist. It patches INSIDE `unstable` (hence after overlayUnstable) because `unstable` is
      # another import of nixpkgs, which the overlays here do not reach.
      #   version: read from the package.json of the tarball itself. The input is already a
      #            store path at eval time, so it is a plain readFile: no IFD, no second hash
      #            to maintain.
      #   sourceRoot: the flake tarball fetcher STRIPS the top-level dir (VSCode-linux-x64),
      #               unlike the nixpkgs fetchurl (which uses sourceRoot = "").
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

      # btop with Intel Xe GPU support: TEMPORARY, with an explicit expiry date.
      #
      # btop 1.4.7 (the one in nixpkgs) ALREADY ships `-DBTOP_GPU=ON`; the gap is neither a
      # build flag nor a root permission, it is that its Intel backend is i915 and ONLY i915.
      # The Arc B580 is Battlemage, runs on the `xe` driver, and i915 does not even support that
      # chip. Measured on the 1.4.7 binary: only `i915`/`intel_i915_info` exist, no reference to
      # `xe`. Which means `sudo btop` would show nothing either: there is no code to read the
      # counter. Upstream: issues #1407 (the Xe feature request) and #1073 (this card, B580) are
      # both OPEN.
      #
      # PR #1457 implements Xe (util through fdinfo with a gtidle/PMU fallback, clock through
      # sysfs, dedicated VRAM, power through hwmon) and was tested on a B580. Here it runs
      # WITHOUT root.
      #
      # Why the whole fork and not `patches = [ (fetchpatch ...) ]`, which would be the smaller
      # delta: the PR is against `main`, and the diff does NOT apply on top of tag v1.4.7 (`git
      # apply --check` fails at src/linux/btop_collect.cpp:317). Swapping the `src` is the same
      # pattern as overlayVscodeTarball above: the nixpkgs recipe, code from somewhere else.
      #
      # REMOVE once #1457 merges and the release carrying it reaches the channel: delete this
      # overlay, its line in the overlay list and the `btop` in packages.${system}. Then
      # `pkgs.btop` goes back to being the nixpkgs one, Xe included. (Rule: zero legacy, this
      # must not become furniture.)
      #
      # version: the nixpkgs convention for an unreleased snapshot (`-unstable-<commit date>`),
      #          because the fork's CMakeLists still says 1.4.7 and calling it plain "1.4.7"
      #          would hide that it is not the release. Since the binary reports 1.4.7 and not
      #          this string, versionCheckHook would fail it, hence doInstallCheck = false.
      # changelog: the nixpkgs one is interpolated with the version and would point at a tag
      #            that does not exist; here the PR itself is what counts.
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

      # LOCAL packages (outside nixpkgs), packaged in ./pkgs and exposed as `pkgs.<name>`.
      # callPackage injects the deps automatically.
      overlayLocalPkgs = final: _: {
        claude-code-discord-status = final.callPackage ./pkgs/claude-code-discord-status.nix { };
        azure-mcp = final.callPackage ./pkgs/azure-mcp.nix { }; # Azure MCP Server (`azmcp`), only in claude-fai
        nxbender = final.callPackage ./pkgs/nxbender.nix { }; # FOSS client for the SonicWall VPN (FAI)
        vscode-bump = final.callPackage ./pkgs/vscode-bump.nix { }; # bumps vscode-tarball to the latest stable
        curseforge = final.callPackage ./pkgs/curseforge.nix { }; # official modpack AppImage (unfree)
        curseforge-bump = final.callPackage ./pkgs/curseforge-bump.nix { }; # version+hash of curseforge.nix
        curseforge-fix-perms = final.callPackage ./pkgs/curseforge-fix-perms.nix { }; # +x on what the app unpacks
      };

      # Claude Desktop: forces the secret backend. Electron autodetects it from
      # XDG_CURRENT_DESKTOP, "Hyprland" matches no case in Chromium's os_crypt, it falls back
      # to "basic text" and safeStorage then declares itself unavailable, so the app warns
      # "your sign-in won't be saved" and asks for a login EVERY time. It is the SAME bug and
      # the SAME remedy as VS Code (home/packages.nix), but without `commandLineArgs` (this is
      # not the nixpkgs electron), hence the wrapper. Only `claude-desktop` is wrapped: the
      # upstream overlay builds the -fhs variant on top of `final.claude-desktop`, which is the
      # FIXPOINT one, so the FHS variant inherits this wrap by itself.
      overlayClaudeKeyring = _: prev: {
        claude-desktop = prev.claude-desktop.overrideAttrs (old: {
          postInstall = (old.postInstall or "") + ''
            wrapProgram $out/bin/claude-desktop --add-flags "--password-store=gnome-libsecret"
          '';
        });
      };

      # A host = the COMMON modules (overlay, sops, disko, ./system, home-manager) + the
      # host's own FOLDER. A new host? Create hosts/<host>/ (default.nix + disko.nix +
      # services.nix) and add one line to nixosConfigurations below.
      #   sudo nixos-rebuild switch --flake .#<host>
      # (home-manager comes in as a module, so one rebuild applies system + user.)
      #
      # What belongs to the HOST and not to ./system: hostname, disks, kernel, monitors,
      # stateVersion and the my.services panel. system/ declares the options; the host answers
      # them (see convention 6 in the README).
      mkHost =
        hostModule:
        nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; };
          modules = [
            # `hostPlatform` instead of the `system` argument of nixosSystem: nixpkgs itself
            # calls that one a "legacy" output and zeroes it in the flake wrapper:
            # «Allow system to be set modularly in nixpkgs.system. We set it to null,
            # to remove the "legacy" entrypoint's non-hermetic default.» (nixpkgs/flake.nix).
            # Its default is `builtins.currentSystem`, which is IMPURE; declaring it as a module
            # option is the hermetic way, and a cross-compiled host would only override it here.
            { nixpkgs.hostPlatform = system; }

            # `unstable.*` + local packages (./pkgs) + claude-desktop (a flake; an overlay
            # instead of packages.<system> so it builds against THIS base, with no 3rd nixpkgs)
            # (overlayClaudeKeyring comes AFTER the upstream one: it re-wraps their package)
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
        # The ONLY host: NVMe Kingston KC3000, ASUS EX-B560M-V5 motherboard, btrfs with
        # subvolumes ready for impermanence. Declarative disk through disko.
        # A new host? hosts/<host>/ + one line here.
        #   sudo nixos-rebuild switch --flake .#nixos-kingston
        nixos-kingston = mkHost ./hosts/nixos-kingston;
      };

      # What THIS repo packages or re-wraps, exposed piece by piece:
      #   nix build .#nxbender
      # They used to exist only inside the overlay, which made them unbuildable in isolation:
      # there was no way to test a patch without going through a whole rebuild.
      #
      # `pkgs` comes from the HOST ITSELF and not from a fresh `import nixpkgs`, for two
      # reasons: it is the SAME object the system installs (so the check below cannot diverge
      # from what the machine receives, rule 14), and it does not add a 2nd nixpkgs
      # instantiation to the evaluation (the same care as pkgsUnstable above).
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
            curseforge-bump # ./pkgs: same, shellcheck at build time
            curseforge-fix-perms # ./pkgs: same
            curseforge # ./pkgs: the official AppImage (outside the CHECK below, the why is there)
            btop # nixpkgs + the src from PR #1457 (Intel Xe GPU): here so the check COMPILES the fork
            ;
          inherit (pkgs.unstable) vscode; # the unstable recipe with the SRC from the official tarball
        };

      # `nix fmt`: the repo's formatter. Without this output, nixfmt would exist ONLY inside VS
      # Code (through nixd/nix-ide), and "the repo style" would depend on which editor someone
      # opened. Declaring it here makes the standard verifiable from outside the editor, which
      # is what a CI would use. nixfmt is the OFFICIAL formatter since RFC 166 (the same one
      # nixpkgs adopted), so this is aligning with upstream, not picking a taste.
      #
      # `nixfmt-tree` and NOT bare `nixfmt`: both reasons came from a real mistake (03/08):
      #   1. `nix fmt` with no path passes no argument, and bare nixfmt falls back to the STDIN
      #      invocation (the deprecated one) with an empty stdin, so "unexpected end of input".
      #   2. `nix fmt .` makes bare nixfmt walk the WHOLE tree, including the ./result symlink
      #      of a `nixos-rebuild build`. It walked into /nix/store and died with
      #      "openTempFileWithDefaultPermissions: permission denied (Read-only file system)"
      #      trying to format a .nix inside bitwarden's node_modules.
      # The wrapper (treefmt) fixes both: it works with no argument and respects the .gitignore,
      # so it never leaves what is versioned. nixfmt's own warning recommends exactly it.
      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-tree;

      # QUALITY GATE: ONE definition, TWO consumers. Both `nix flake check` and the pre-commit
      # hook are born here. They used to be three hand-made derivations linting exactly what the
      # hooks were going to lint: two definitions of the same rule, which is the recipe for the
      # silent drift of rule 14 (the gate passes, the hook fails, and nobody understands why).
      # git-hooks.nix collapses the two.
      #
      # And the CI (.github/workflows/nix.yml) became the THIRD consumer of the same definition
      # on 04/08/2026: it runs `nix flake check` with `--override-input duo-streak-daemon
      # path:./ci/stub-duo` (the stub avoids needing a deploy key for the private input). Which
      # means touching the hooks below changes the CI by itself: there is no second list of
      # linters in the workflow anymore.
      checks.${system} = {
        pre-commit = inputs.git-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            # nixfmt-rfc-style and NOT `nixfmt`: in this hook set the name `nixfmt` still points
            # at the classic one. Asking for the wrong one would reformat the repo in the old
            # style, the same naming care as home/packages.nix.
            # (04/08/2026: `nix flake check` already WARNS "nixfmt-rfc-style is now the same as
            # pkgs.nixfmt which should be used instead", so the distinction above is expiring in
            # nixpkgs. Once the git-hooks.nix hook set follows, the right name goes back to
            # being `nixfmt`; until then, switching would reformat in the old style.)
            nixfmt-rfc-style.enable = true;
            # Both read the repo config (./statix.toml) because they run with cwd at the root.
            statix.enable = true;
            deadnix.enable = true;
            # Covers the `.sh` files in ./scripts: rule 7 says the logic lives in the build, and
            # sync-secrets.sh already gets shellcheck for free by coming from a
            # writeShellApplication. owfetch.sh does NOT: it runs in ash on OpenWrt, not here,
            # so no derivation wraps it. Without this hook, the only `.sh` in the repo that runs
            # on SOMEONE ELSE'S machine would be the only one with no verification.
            shellcheck.enable = true;
          };
        };

        # BUILDS what the repo packages, the part the gate did NOT cover (04/08/2026).
        # `nix flake check` builds what is in `checks` («the derivations specified by the
        # flake's checks output can be built successfully»), but of `nixosConfigurations` it
        # only requires that the toplevel «must be derivations»: it EVALUATES the host and stops
        # there. Measured before this line, the check printed "running 1 flake checks...", and
        # the only thing built was pre-commit.
        #
        # The difference matters because what is fragile here is not evaluation, it is
        # PACKAGING: nxbender's 3 patches, vscode's `sourceRoot = "source"` and the wrapProgram
        # over claude-desktop's .deb are assumptions about someone else's tree. None of them
        # breaks at eval, they break at build, AFTER a `nix flake update`. And `upgrade` is
        # `update && nh os switch`, so the breakage landed in the middle of the switch.
        #
        # linkFarm and not symlinkJoin: a farm does not merge directories, so two packages with
        # the same `bin/` do not collide. The derivation is disposable, the value is the build.
        #
        # DELIBERATELY not `system.build.toplevel`: building the whole system on the GitHub
        # runner would drag in quickshell (Qt/C++). Only the packages this repo controls come in
        # here, which is where the patches can rot.
        # `curseforge` stays OUT, and it is the only exception: its src is a POINTER URL
        # (`curseforge-latest-linux.AppImage`, since Overwolf publishes no versioned URL), so on
        # every release of theirs the pinned hash stops matching and the check would go RED for
        # something that is not in this repo. It is the same pain as VS Code's `/latest/`,
        # except there is no fixed URL to pick here: the remedy is `curseforge-bump` (which runs
        # on `update` and DOES enter the check, because its shellcheck is stable). Testing the
        # packaging is still `nix build .#curseforge`, by hand.
        #
        # The attribute keeps its pt-BR name on purpose: `checks.pacotes` is cited BY NAME in
        # the comments of .github/workflows/nix.yml, so renaming it here alone would leave that
        # file lying. It goes out when that workflow is translated (rule 17).
        pacotes = nixpkgs.legacyPackages.${system}.linkFarm "checks-pacotes-do-repo" (
          nixpkgs.lib.mapAttrsToList (name: path: { inherit name path; }) (
            removeAttrs self.packages.${system} [ "curseforge" ]
          )
        );
      };

      # devShell: it exists for a CONCRETE reason, not for completeness. Entering it is what
      # INSTALLS the hook into .git/hooks/pre-commit (the `shellHook` from git-hooks does that).
      # Without it, "we have pre-commit" would be a lie: the hook file would never appear. With
      # direnv (home/shell/direnv.nix) a `cd` into the repo already enters here, so the hook
      # installs itself in any fresh clone.
      #
      # `enabledPackages` brings statix/deadnix/nixfmt at the version the hooks use, so running
      # them by hand inside the shell is identical to what the hook will run.
      devShells.${system}.default =
        let
          pkgs = nixpkgs.legacyPackages.${system};
          inherit (self.checks.${system}.pre-commit) shellHook enabledPackages;
        in
        # mkShellNoCC and NOT mkShell: nothing here compiles C, they are Nix linters and the LSP.
        # mkShell drags in the stdenv with the cc/binutils wrapper, and the VISIBLE effect is
        # direnv dumping a paragraph of `export +AR +AS +CC +CXX +LD +NM +OBJCOPY +RANLIB
        # +NIX_CFLAGS_COMPILE +NIX_HARDENING_ENABLE ...` on every `cd` into the repo. Without the
        # CC that shortens to what matters, and the shell is lighter to build.
        pkgs.mkShellNoCC {
          inherit shellHook;
          buildInputs = enabledPackages ++ [ pkgs.nixd ];
        };
    };
}
