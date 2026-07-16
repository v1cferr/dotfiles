{
  description = "Sistema declarativo do v1cferr — NixOS (nixos-seagate) + home-manager unificados";

  inputs = {
    # BASE do sistema: canal ESTÁVEL (release, tipo Debian/Ubuntu, ~6 meses).
    # É onde a maioria dos pacotes fica — previsível, sem surpresa.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # BLEEDING-EDGE sob demanda: canal unstable (rolling, tipo Arch). NÃO é a
    # base — só alimenta o overlay `unstable.*` pra pacotes escolhidos a dedo.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      # Branch de release CASA com o nixpkgs estável (evita mismatch de opções).
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Particionamento declarativo — reservado p/ futuros hosts bare-metal.
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Segredos criptografados versionados no repo (senha, tokens…). A chave-mestra
    # age fica FORA do git e é a única coisa a carregar no cutover.
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, disko, sops-nix, ... }@inputs:
    let
      system = "x86_64-linux";

      # Overlay que expõe `pkgs.unstable.<pacote>` = versão do canal unstable,
      # mantendo TODO o resto do sistema na base estável. É isso que dá a
      # escolha por pacote: `pkgs.foo` (estável) vs `pkgs.unstable.foo` (última).
      overlayUnstable = final: prev: {
        unstable = import nixpkgs-unstable {
          inherit system;
          config.allowUnfree = true;
        };
      };
    in
    {
      # ── Sistema + usuário, UM comando, atômico ─────────────────────────────
      #   sudo nixos-rebuild switch --flake .#nixos-seagate
      # O home-manager entra como módulo do NixOS: o mesmo rebuild aplica o
      # sistema (root) e cria os symlinks do usuário (~/.config) de uma vez.
      nixosConfigurations.nixos-seagate = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          { nixpkgs.overlays = [ overlayUnstable ]; } # habilita `unstable.*`
          sops-nix.nixosModules.sops
          ./system

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true; # usa o nixpkgs do sistema (+ overlay)
            home-manager.useUserPackages = true; # instala no perfil do usuário
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.users.v1cferr = import ./home;
          }
        ];
      };
    };
}
