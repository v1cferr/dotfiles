# The packages output: what THIS repo builds, plus the evaluated facts, the stats, the canary's
# probe, the site with its stats and the two VM drills. The why per entry: docs/notes/repo/flake.md
{
  self,
  inputs,
  system,
  commonModules,
}:

let
  inherit (inputs) nixpkgs;
  # THE REFERENCE HOST, named once (rule 11): the packages, the facts, the probe and both VM drills
  # are built from it. A second host changes this name and nothing else here.
  hostName = "ex-b560m-v5";
  host = self.nixosConfigurations.${hostName};
  hostDir = ../hosts + "/${hostName}";
  # `nix build .#nxbender` works in isolation, and `pkgs` comes from the HOST, so the check cannot
  # diverge from what the machine gets (rule 14).
  inherit (host) pkgs;
in
{
  inherit (pkgs)
    claude-code-discord-status # ./pkgs: the Rich Presence daemon
    nxbender # ./pkgs: the SonicWall VPN client (3 patches on top of upstream)
    claude-desktop # someone else's flake + the keyring wrapper from here
    codex # ./pkgs: the official binary, so the check proves the fetch and the wrapper
    antigravity-cli # ./pkgs: the official binary, so the check proves the fetch and the patchelf
    basic-memory # ./pkgs: building it IS the proof that our uv.lock still resolves
    vendored-bump # ./tools: same, and building it proves every updateScript still resolves
    curseforge-fix-perms # ./pkgs: same
    stack-wallet # ./pkgs: the official AppImage at a VERSIONED url, so unlike curseforge it stays in the check
    docs-links # ./tools: the build IS the script's flake8; the CHECK below runs it
    docs-site # ./tools: the static export, so the CHECK below proves the site builds
    docs-site-check # ./tools: the build IS the wrapper's shellcheck; the HOOK below runs it
    prose-style # ./tools: same flake8 at build time; the HOOKS below run it, in two modes
    qml-syntax # ./tools: the build IS the wrapper's shellcheck; the HOOK below runs it
    data-syntax # ./tools: same flake8 at build time; the HOOK below runs it
    dead-config # ./tools: same, and the CHECK below runs it too
    router-ssot # ./tools: same, and the CHECK below runs it too
    eval-metrics # ./tools: same flake8 at build time; the gate WORKFLOW runs it after the check
    usage-audit # ./tools: same flake8 at build time; I run it by hand, it reads my ~
    rules-index # ./tools: same, and the CHECK below runs it too
    curseforge # ./pkgs: the official AppImage (outside the CHECK below, the why is there)
    btop # nixpkgs + the src from PR #1457 (Intel Xe GPU): here so the check COMPILES the fork
    ;
  inherit (pkgs.unstable) vscode; # the unstable recipe with the SRC from the official tarball

  # THE EVALUATED STATE, for a reader who would otherwise have to INFER it from Nix, which
  # the rule 16 secrets episode proved is not always possible: docs/notes/repo/flake.md
  system-facts =
    let
      cfg = host.config;
      inherit (nixpkgs) lib;
    in
    pkgs.writeText "system-facts.json" (
      builtins.toJSON {
        host = {
          hostname = cfg.networking.hostName;
          inherit system;
          stateVersion = cfg.system.stateVersion;
          homeStateVersion = cfg.home-manager.users.v1cferr.home.stateVersion;
          kernel = cfg.boot.kernelPackages.kernel.version;
          uiFont = cfg.my.fonts.ui;
        };
        # The host's own panel: which optional services THIS machine turns on.
        services = cfg.my.services;
        # `auth` is dropped: it names the variables holding password hashes, and a facts
        # file that lists them teaches an attacker where to look for nothing.
        ingress = lib.mapAttrs (_: s: {
          inherit (s) expose upstream;
          routes = lib.attrNames s.routes;
        }) cfg.my.ingress;
        monitors = cfg.my.monitors;
        filesystems = lib.mapAttrs (_: f: f.fsType) cfg.fileSystems;
        firewall = {
          inherit (cfg.networking.firewall) allowedTCPPorts allowedUDPPorts;
        };
        # NAMES only. A value here would be rule 12 broken in one line.
        secrets = lib.attrNames cfg.sops.secrets;
        # What the lock actually pinned, so "which revision am I on" needs no lock reading.
        inputs = lib.mapAttrs (_: i: i.rev or i.narHash or "unknown") (removeAttrs inputs [ "self" ]);
      }
    );

  # THE README'S NUMBERS, counted from this very source at build, so a commit and its stats
  # cannot disagree. The facts only Nix knows come in here: docs/notes/repo/readme.md
  repo-stats = pkgs.callPackage ../tools/repo-stats/package.nix {
    src = self;
    facts =
      let
        lock = builtins.fromJSON (builtins.readFile ../flake.lock);
        inherit (self.checks.${system}.pre-commit.config) hooks;
      in
      {
        release = lock.nodes.nixpkgs.original.ref;
        inputs = builtins.length (builtins.attrNames lock.nodes.root.inputs);
        hooks = builtins.length (builtins.filter (h: h.enable) (builtins.attrValues hooks));
        date = self.lastModifiedDate or "19700101000000";
      };
  };

  # THE HOUSE FROM OUTSIDE, for the canary: the anchor and the port come from the host's own
  # config, the expected forwards from the router's mirror: docs/notes/network/exposure.md
  exposure-check =
    let
      cfg = host.config;
    in
    pkgs.callPackage ../tools/exposure-check/package.nix {
      host = "ssh.${cfg.my.net.domain}";
      sshPort = builtins.head cfg.services.openssh.ports;
      inherit (cfg.my.router) mirror;
    };

  # WHAT GITHUB PAGES SERVES: the site plus the stats under /stats, joined here and not
  # inside docs-site, whose src stays fenced to docs/ so a modules/ commit does not rebuild it.
  pages = pkgs.runCommand "pages" { } ''
    cp -r ${pkgs.docs-site} $out
    chmod -R u+w $out
    cp -r ${self.packages.${system}.repo-stats} $out/stats
  '';

  # THE STATE COMING BACK, from the installer: `nix run .#restore-state`. Built from the host so it
  # restores exactly what the backup takes: docs/guides/disaster-recovery.md
  restore-state = host.config.my.backup.restoreState;

  # THE DISK LAYOUT, formatted from scratch and booted: `nix run .#disko-vm`. The REAL
  # disko config on a 24 GiB image, and the only check of it: docs/notes/boot-and-storage/disko.md
  disko-vm =
    (nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs; };
      modules = commonModules ++ [
        hostDir
        (hostDir + "/vm-disko.nix")
      ];
    }).config.system.build.vmWithDisko;

  # THE BOOT TEST: it boots THIS host in QEMU and reads which units actually came up. A
  # PACKAGE and not a check on purpose, the gate reason is in docs/notes/repo/vm-boot.md
  vm-boot = import ./vm-boot.nix {
    inherit
      inputs
      pkgs
      commonModules
      hostDir
      ;
  };
}
