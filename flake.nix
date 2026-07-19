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

    # Zen Browser — NÃO está no nixpkgs; este flake segue os releases do upstream.
    # "Sempre a última versão" = bump com `nix flake update zen-browser`.
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager"; # dedup: evita home-manager_2 no lock
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

      # Um host = módulos COMUNS (overlay, sops, disko, ./system, home-manager) +
      # o arquivo específico do host. Novo host? Cria hosts/<host>.nix e adiciona
      # uma linha em nixosConfigurations abaixo.
      #   sudo nixos-rebuild switch --flake .#<host>
      # (home-manager entra como módulo → um rebuild aplica sistema + usuário.)
      mkHost = hostModule: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          { nixpkgs.overlays = [ overlayUnstable ]; } # habilita `unstable.*`
          sops-nix.nixosModules.sops
          disko.nixosModules.disko # inerte em hosts sem disko.devices
          ./system
          hostModule

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true; # usa o nixpkgs do sistema (+ overlay)
            home-manager.useUserPackages = true; # instala no perfil do usuário
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.users.v1cferr = import ./home;
          }
        ];
      };
    in
    {
      nixosConfigurations = {
        # Instalação ATUAL (HDD Seagate)
        nixos-seagate = mkHost ./hosts/nixos-seagate.nix;
        # ALVO ATIVO do cutover (SSD SanDisk, SATA) — preserva o Arch no Kingston
        nixos-sandisk = mkHost ./hosts/nixos-sandisk.nix;
        # Alternativa dormente (SSD Kingston, NVMe) — apagaria o Arch; não é o plano
        ex-b560m-v5 = mkHost ./hosts/ex-b560m-v5.nix;
      };
    };
}
