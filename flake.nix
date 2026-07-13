{
  description = "Sistema declarativo do v1cferr — hoje Arch (stow), amanhã NixOS (ver NIXOS-MIGRATION.md)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Particionamento declarativo (usado na fase bare metal)
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, disko, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      # ── NixOS ────────────────────────────────────────────────────────────
      # VM de teste (direto do Arch, com nix instalado):
      #   nix build .#nixosConfigurations.staging.config.system.build.vm
      #   ./result/bin/run-nixos-staging-vm
      nixosConfigurations.staging = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./nix/hosts/staging.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.v1cferr = import ./nix/home/v1cferr.nix;
          }
        ];
      };

      # ── home-manager standalone (fase de aprendizado, NO Arch) ──────────
      # 1ª vez:  nix run github:nix-community/home-manager -- switch --flake .#v1cferr@arch
      # depois:  home-manager switch --flake .#v1cferr@arch
      homeConfigurations."v1cferr@arch" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./nix/home/v1cferr.nix ];
      };
    };
}
