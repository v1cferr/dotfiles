{
  description = "Sistema declarativo do v1cferr — NixOS (nixos-kingston) + home-manager unificados";

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

    # Tema do GRUB estilo "seleção de mundo" do Minecraft — cada SO/geração vira um
    # "mundo" com ícone e descrição. É o do dualboot NixOS ⇄ Windows 11, ATIVO em
    # system/core/boot.nix. O outro tema do mesmo autor (minegrub-theme, o menu
    # principal do Minecraft) foi preterido: entrada vira botão, sem ícone por SO.
    minegrub-world-sel-theme = {
      url = "github:Lxtharia/minegrub-world-sel-theme";
      inputs.nixpkgs.follows = "nixpkgs"; # dedup: não puxa um 2º nixpkgs pro lock
    };

    # Quickshell — shell/bar em QML (outfoxxed), NÃO no nixpkgs. "Sempre a última":
    # bump com `nix flake update quickshell`. A config QML mora no repo
    # (home/desktop/quickshell/) e é linkada por mkOutOfStoreSymlink → hot-reload.
    quickshell = {
      url = "git+https://git.outfoxxed.me/quickshell/quickshell";
      inputs.nixpkgs.follows = "nixpkgs"; # dedup
    };

    # Google Chrome canais DEV/BETA — o nixpkgs só empacota o stable. Este flake
    # mantido (nix-community) traz o google-chrome-dev sempre fresco; "latest" = bump
    # com `nix flake update browser-previews`. Usado em home/packages.nix.
    browser-previews = {
      url = "github:nix-community/browser-previews";
      inputs.nixpkgs.follows = "nixpkgs"; # dedup (derivation própria, sem dep do unstable)
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

      # Pacotes LOCAIS (fora do nixpkgs), empacotados em ./pkgs e expostos como
      # `pkgs.<nome>`. callPackage injeta as deps automaticamente.
      overlayLocalPkgs = final: prev: {
        claude-code-discord-status =
          final.callPackage ./pkgs/claude-code-discord-status.nix { };
        nxbender = final.callPackage ./pkgs/nxbender.nix { }; # cliente FOSS da VPN SonicWall (FAI)
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
          { nixpkgs.overlays = [ overlayUnstable overlayLocalPkgs ]; } # `unstable.*` + pacotes locais (./pkgs)
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
        # ÚNICO host — NVMe Kingston KC3000, MOBO ASUS EX-B560M-V5, btrfs com
        # subvolumes prontos pra impermanência. Disco declarativo via disko.
        # Novo host? hosts/<host>/ + uma linha aqui.
        #   sudo nixos-rebuild switch --flake .#nixos-kingston
        nixos-kingston = mkHost ./hosts/nixos-kingston;
      };
    };
}
