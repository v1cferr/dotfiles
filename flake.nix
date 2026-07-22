{
  description = "Sistema declarativo do v1cferr — NixOS (nixos-sandisk) + home-manager unificados";

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

    # duo-streak-daemon — o app (daemon Playwright + API + web + Docker) mora no
    # SEU repo. Aqui é só DEPLOY: fixamos o commit no flake.lock (bump com
    # `nix flake update duo-streak-daemon`) e o docker-compose builda do store-path.
    # flake = false: é um repo de código comum, não expõe outputs Nix.
    duo-streak-daemon = {
      # Repo PRIVADO → git+ssh (reusa a chave SSH; sem token no sops). O `nix flake
      # lock`/update roda como USUÁRIO (tem a chave) e popula a store; o rebuild
      # como root reusa o store-path já fixado, sem re-fetch.
      url = "git+ssh://git@github.com/v1cferr/duo-streak-daemon.git";
      flake = false;
    };

    # Tema do GRUB estilo "seleção de mundo" do Minecraft (pro dualboot Arch/NixOS/
    # Windows). SÓ tem efeito quando system/boot.nix flipar `useGrub = true` (em
    # casa); enquanto false, o input fica travado no lock mas inerte.
    minegrub-world-sel-theme = {
      url = "github:Lxtharia/minegrub-world-sel-theme";
      inputs.nixpkgs.follows = "nixpkgs"; # dedup: não puxa um 2º nixpkgs pro lock
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
        # Instalação ATUAL — SSD SanDisk (SATA), MOBO ASUS EX-B560M-V5. Disco
        # declarativo via disko. Novo host? hosts/<host>/ + uma linha aqui.
        #   sudo nixos-rebuild switch --flake .#nixos-sandisk
        nixos-sandisk = mkHost ./hosts/nixos-sandisk;
      };
    };
}
