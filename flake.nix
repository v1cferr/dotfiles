{
  description = "My declarative system: NixOS (ex-b560m-v5) + home-manager, unified";

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

    # spicetify: it BUILDS a patched Spotify derivation instead of mutating the store, which is
    # the only reason this is declarable at all. Why THIS fork: docs/notes/apps/spotify.md
    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs"; # dedup: the packages it uses come from MY pkgs anyway
    };

    # Claude Desktop: not in nixpkgs. This flake repackages the OFFICIAL .deb (the nixpkgs pattern
    # for a vendored binary). The 2 alternatives that were passed over: docs/notes/repo/flake.md
    claude-desktop = {
      url = "github:aaddrick/claude-desktop-debian";
      inputs.nixpkgs.follows = "nixpkgs"; # dedup: only affects the lock (the overlay uses the pkgs FROM HERE)
    };

    # Claude Code SKILLS from someone else's repo, delivered as MANAGED skills by
    # modules/nixos/services/claude-code.nix. flake = false: it is markdown, exposing no Nix outputs.
    mattpocock-skills = {
      url = "github:mattpocock/skills";
      flake = false;
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

    # uv2nix and its two halves: they turn a `uv.lock` into a Nix package set, which is how
    # basic-memory gets built. Why not nixpkgs: docs/notes/apps/basic-memory.md
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs"; # dedup
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # The OUTPUTS are wiring only: each one is implemented in ./flake/, and this is where they meet.
  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";

      # The overlays every host gets, in order, and how a host is assembled from them.
      overlays = import ./flake/overlays.nix { inherit inputs system; };
      hosts = import ./flake/hosts.nix { inherit inputs system overlays; };
    in
    {
      nixosConfigurations = {
        # The ONLY host: an NVMe Kingston KC3000 on an ASUS EX-B560M-V5, btrfs through disko.
        #   sudo nixos-rebuild switch --flake .#ex-b560m-v5
        ex-b560m-v5 = hosts.mkHost ./hosts/ex-b560m-v5;
      };

      packages.${system} = import ./flake/packages.nix {
        inherit self inputs system;
        inherit (hosts) commonModules;
      };

      # `nix fmt`, so the standard is verifiable OUTSIDE the editor. `nixfmt-tree` and not bare nixfmt,
      # which breaks with no argument AND walks into ./result: docs/notes/repo/flake.md
      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-tree;

      checks.${system} = import ./flake/checks.nix { inherit self inputs system; };

      devShells.${system}.default = import ./flake/dev-shell.nix { inherit self inputs system; };
    };
}
