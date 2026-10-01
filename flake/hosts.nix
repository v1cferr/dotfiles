# How a host is assembled: the modules EVERY host gets, plus mkHost, which adds the host's own
# folder. The hosts themselves are wired in flake.nix: docs/notes/repo/flake.md
{
  inputs,
  system,
  overlays,
}:

let
  inherit (inputs)
    nixpkgs
    home-manager
    disko
    sops-nix
    ;
in
rec {
  # The modules EVERY host gets, hoisted OUT of mkHost so the boot test can build the same list
  # plus its own overrides: one definition, two consumers, instead of a copy that drifts.
  commonModules = [
    # `hostPlatform` and not nixosSystem's `system`, which nixpkgs itself calls legacy and zeroes:
    # its default is builtins.currentSystem, which is IMPURE. As a module option it is hermetic.
    { nixpkgs.hostPlatform = system; }

    # The overlays, in order: ./overlays.nix.
    { nixpkgs.overlays = overlays; }
    sops-nix.nixosModules.sops
    disko.nixosModules.disko # inert on hosts with no disko.devices
    ../modules/nixos

    home-manager.nixosModules.home-manager
    {
      home-manager.useGlobalPkgs = true; # uses the system nixpkgs (+ overlay)
      home-manager.useUserPackages = true; # installs into the user profile
      home-manager.extraSpecialArgs = { inherit inputs; };
      home-manager.users.v1cferr = import ../modules/home;
    }
  ];

  # A host = the COMMON modules plus its own FOLDER. hostname/disks/kernel/monitors/stateVersion
  # and the my.services panel belong to the HOST; modules/nixos/ only declares the options.
  mkHost =
    hostModule:
    nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs; };
      modules = commonModules ++ [ hostModule ];
    };
}
