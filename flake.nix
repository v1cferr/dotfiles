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

    # Claude Desktop — NÃO está no nixpkgs (a issue #366213 foi fechada; o canal só
    # tem claude-code/claude-monitor). Este flake REEMPACOTA o .deb OFICIAL que a
    # Anthropic passou a publicar em 30/06/2026 (beta Linux, APT próprio) — padrão
    # nixpkgs de vendor binário (dpkg-deb + autoPatchelfHook), como discord/vscode.
    # Preterido: k3d3/claude-desktop-linux-flake (o pioneiro, mas fazia RE do binário
    # de Windows e está parado desde nov/2025) e heytcass/claude-for-linux (extrai do
    # DMG do macOS; 6 estrelas, 77 issues). CI do upstream bumpa versão+hash sozinha,
    # então "última versão" = `nix flake update claude-desktop`.
    claude-desktop = {
      url = "github:aaddrick/claude-desktop-debian";
      inputs.nixpkgs.follows = "nixpkgs"; # dedup: só afeta o lock (o overlay usa o pkgs DAQUI)
    };

    # git-hooks.nix — pre-commit gerenciado por Nix. É o que faz o lint pegar ANTES do
    # commit em vez de depois do push: sem ele, `nix flake check` e o CI só reprovam
    # quando o erro já está na história. As HOOKS ficam declaradas em checks abaixo, e
    # o `shellHook` que instala o .git/hooks/pre-commit vem do devShells.
    # (cachix/git-hooks.nix é o nome atual; o repo antigo pre-commit-hooks.nix redireciona.)
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs"; # dedup: statix/deadnix/nixfmt vêm da MESMA base
    };

    # Google Chrome canais DEV/BETA — o nixpkgs só empacota o stable. Este flake
    # mantido (nix-community) traz o google-chrome-dev sempre fresco; "latest" = bump
    # com `nix flake update browser-previews`. Usado em home/packages.nix.
    browser-previews = {
      url = "github:nix-community/browser-previews";
      inputs.nixpkgs.follows = "nixpkgs"; # dedup (derivation própria, sem dep do unstable)
    };

    # VS Code na ÚLTIMA versão DE VERDADE. Nem o unstable entrega isso: o bump é humano/bot
    # e fica 3-14 dias atrás, às vezes PULANDO release (1.125→1.127, 1.127→1.129.1 em jul/26).
    # A causa é estrutural — o auto-updater do VS Code não roda com a store read-only, então a
    # versão é literalmente o que está no lock. Aqui o lock passa a ser o TARBALL OFICIAL do
    # canal stable: a URL `/latest/` não muda, mas o conteúdo sim, e o `nix flake update`
    # re-resolve e grava o narHash novo → `upgrade` já traz a versão do dia, sem hash na mão.
    # NÃO é o Insiders (build de teste diária): é o mesmo stable que a Microsoft serve, só sem
    # esperar o nixpkgs. `flake = false` porque é um tarball, não um flake.
    #
    # ⚠️ CUSTO, o outro lado do "sempre a última" (medido em 04/08/2026): tarball não tem rev, então o lock guarda
    # SÓ o narHash — e a URL `/latest/` é alvo MÓVEL. No dia em que a Microsoft rotacionar o conteúdo, ninguém no
    # mundo serve mais aquele hash, e COMMIT ANTIGO deste repo deixa de ser construível. É o único input que fura
    # a "cápsula do tempo" da regra 13 — trade-off aceito de propósito, mas o preço é este. Se um dia precisar de
    # um ponto reproduzível de verdade, trocar `/latest/` por `/<versão>/` (a API de update serve URL versionada)
    # devolve hash estável.
    vscode-latest = {
      url = "tarball+https://update.code.visualstudio.com/latest/linux-x64/stable";
      flake = false;
    };
  };

  outputs =
    {
      self, # usado em devShells (lê o shellHook do checks.pre-commit)
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      disko,
      sops-nix,
      ...
    }@inputs:
    let
      system = "x86_64-linux";

      # UMA instância do canal unstable, criada FORA do overlay de propósito. Dentro
      # dele, o `import` corre por instância de `pkgs` — e overlay vale também pros
      # SPLICES (`pkgsi686Linux`, que o Steam instancia por causa do 32-bit): no dia
      # que alguém tocar `pkgs.pkgsi686Linux.unstable`, a árvore unstable seria
      # importada OUTRA vez. Hoje é lazy e não custa nada; içar o import é o que
      # garante que continue assim. É também a forma que a comunidade associa a OOM
      # em avaliação (discourse 1517) — o custo aparece quando as instâncias somam.
      pkgsUnstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };

      # Overlay que expõe `pkgs.unstable.<pacote>` = versão do canal unstable,
      # mantendo TODO o resto do sistema na base estável. É isso que dá a
      # escolha por pacote: `pkgs.foo` (estável) vs `pkgs.unstable.foo` (última).
      overlayUnstable = _: _: { unstable = pkgsUnstable; };

      # Troca só o SRC do vscode pelo tarball do input vscode-latest, mantendo a RECEITA do
      # unstable — o generic.nix do nixpkgs tem lógica versionada (`versionAtLeast
      # vscodeVersion "1.129.0"`), então patchar receita fresca é o delta mínimo; sobre a
      # receita da 26.05 (era 1.119) o salto de 12 versões passaria por ramos que não existem.
      # Patcha DENTRO de `unstable` (por isso vem depois do overlayUnstable) porque `unstable`
      # é outro import de nixpkgs, que os overlays daqui não alcançam.
      #   version: lido do package.json do próprio tarball. O input já é store path em eval,
      #            então é readFile puro — sem IFD, sem hash duplicado pra manter.
      #   sourceRoot: o fetcher de tarball do flake REMOVE o dir de topo (VSCode-linux-x64),
      #               diferente do fetchurl do nixpkgs (que usa sourceRoot = "").
      overlayVscodeLatest = _: prev: {
        unstable = prev.unstable // {
          vscode = prev.unstable.vscode.overrideAttrs (_: {
            inherit (builtins.fromJSON (builtins.readFile "${inputs.vscode-latest}/resources/app/package.json"))
              version
              ;
            src = inputs.vscode-latest;
            sourceRoot = "source";
          });
        };
      };

      # Pacotes LOCAIS (fora do nixpkgs), empacotados em ./pkgs e expostos como
      # `pkgs.<nome>`. callPackage injeta as deps automaticamente.
      overlayLocalPkgs = final: _: {
        claude-code-discord-status = final.callPackage ./pkgs/claude-code-discord-status.nix { };
        nxbender = final.callPackage ./pkgs/nxbender.nix { }; # cliente FOSS da VPN SonicWall (FAI)
      };

      # Claude Desktop: força o backend de secret. O Electron autodetecta pelo
      # XDG_CURRENT_DESKTOP, "Hyprland" não casa com nenhum caso do os_crypt do
      # Chromium, ele cai no "basic text" e aí o safeStorage se declara indisponível
      # → o app avisa "your sign-in won't be saved" e pede login TODA vez. É o MESMO
      # bug e o MESMO remédio do VS Code (home/packages.nix), mas sem `commandLineArgs`
      # (não é o electron do nixpkgs) — daí o wrapper. Só o `claude-desktop` é
      # embrulhado: o overlay do upstream monta o -fhs sobre `final.claude-desktop`,
      # que é o do FIXPOINT, então a variante FHS herda este wrap sozinha.
      overlayClaudeKeyring = _: prev: {
        claude-desktop = prev.claude-desktop.overrideAttrs (old: {
          postInstall = (old.postInstall or "") + ''
            wrapProgram $out/bin/claude-desktop --add-flags "--password-store=gnome-libsecret"
          '';
        });
      };

      # Um host = módulos COMUNS (overlay, sops, disko, ./system, home-manager) +
      # a PASTA específica do host. Novo host? Cria hosts/<host>/ (default.nix +
      # disko.nix + services.nix) e adiciona uma linha em nixosConfigurations abaixo.
      #   sudo nixos-rebuild switch --flake .#<host>
      # (home-manager entra como módulo → um rebuild aplica sistema + usuário.)
      #
      # O que é do HOST e não do ./system: hostname, discos, kernel, monitores,
      # stateVersion e o painel my.services. O system/ declara as opções; o host
      # responde (ver convenção 6 do README).
      mkHost =
        hostModule:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            # `unstable.*` + pacotes locais (./pkgs) + claude-desktop (flake; overlay
            # em vez de packages.<system> pra buildar contra ESTA base, sem 3º nixpkgs)
            # (o overlayClaudeKeyring vem DEPOIS do upstream: ele reembrulha o pacote dele)
            {
              nixpkgs.overlays = [
                overlayUnstable
                overlayVscodeLatest # DEPOIS do overlayUnstable: patcha o `unstable.vscode` dele
                overlayLocalPkgs
                inputs.claude-desktop.overlays.default
                overlayClaudeKeyring
              ];
            }
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

      # `nix fmt` — formatter do repo. Sem este output, o nixfmt existiria SÓ dentro do
      # VS Code (via nixd/nix-ide), e "o estilo do repo" dependeria de qual editor a
      # pessoa abriu. Declarar aqui torna o padrão verificável de fora do editor, que é
      # o que um CI usaria. nixfmt é o formatter OFICIAL desde a RFC 166 (o mesmo que o
      # nixpkgs adotou), então isto é alinhar com o upstream, não escolher gosto.
      #
      # `nixfmt-tree` e NÃO `nixfmt` cru — os dois motivos vieram de erro real (03/08):
      #   1. `nix fmt` sem caminho não passa argumento, e o nixfmt cru cai na invocação
      #      por STDIN (a deprecada) com stdin vazio → "unexpected end of input".
      #   2. `nix fmt .` faz o nixfmt cru andar a árvore INTEIRA, incluindo o symlink
      #      ./result de um `nixos-rebuild build`. Ele entrou no /nix/store e morreu com
      #      "openTempFileWithDefaultPermissions: permission denied (Read-only file
      #      system)" tentando formatar .nix dentro de node_modules do bitwarden.
      # O wrapper (treefmt) resolve os dois: funciona sem argumento e respeita o
      # .gitignore, então nunca sai do que é versionado. O aviso do próprio nixfmt
      # recomenda exatamente ele.
      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-tree;

      # GATE de qualidade — UMA definição, DOIS consumidores: o `nix flake check` e o
      # hook de pre-commit nascem daqui. Antes eram três derivações artesanais que
      # lintavam exatamente o mesmo que os hooks iriam lintar: duas definições da mesma
      # regra, que é a receita de drift silencioso da regra 14 (o gate passa, o hook
      # reprova, e ninguém entende por quê). O git-hooks.nix colapsa as duas.
      #
      # A terceira definição que SOBRA de propósito é o CI (.github/workflows/nix.yml),
      # que roda as ferramentas direto do nixpkgs em vez de avaliar este flake. Não é
      # descuido: o input privado duo-streak-daemon obrigaria o CI a ter deploy key só
      # pra rodar linters. Custo aceito e declarado — ao mexer nos hooks abaixo, mexer
      # no workflow também.
      checks.${system} = {
        pre-commit = inputs.git-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            # nixfmt-rfc-style e NÃO `nixfmt`: neste conjunto de hooks o nome `nixfmt`
            # ainda aponta pro clássico. Pedir o errado reformataria o repo no estilo
            # velho — o mesmo cuidado de nome do home/packages.nix.
            # (04/08/2026: o `nix flake check` já AVISA "nixfmt-rfc-style is now the same
            # as pkgs.nixfmt which should be used instead" — a distinção acima está
            # expirando no nixpkgs. Quando o hook set do git-hooks.nix acompanhar, o nome
            # certo volta a ser `nixfmt`; até lá, trocar reformataria no estilo velho.)
            nixfmt-rfc-style.enable = true;
            # Ambos leem a config do repo (./statix.toml) porque rodam com o cwd na raiz.
            statix.enable = true;
            deadnix.enable = true;
          };
        };
      };

      # devShell — existe por um motivo CONCRETO, não por completude: entrar nele é o
      # que INSTALA o hook em .git/hooks/pre-commit (o `shellHook` do git-hooks faz
      # isso). Sem ele, "temos pre-commit" seria mentira: o arquivo de hook nunca
      # apareceria. Com o direnv (home/shell/direnv.nix) o `cd` no repo já entra aqui,
      # então o hook se instala sozinho em qualquer clone novo.
      #
      # `enabledPackages` traz statix/deadnix/nixfmt na versão que os hooks usam — logo,
      # rodar na mão dentro do shell é idêntico ao que o hook vai rodar.
      devShells.${system}.default =
        let
          pkgs = nixpkgs.legacyPackages.${system};
          inherit (self.checks.${system}.pre-commit) shellHook enabledPackages;
        in
        # mkShellNoCC e NÃO mkShell: nada aqui compila C — são linters de Nix e o LSP. O
        # mkShell arrasta o stdenv com wrapper de cc/binutils, e o efeito VISÍVEL é o
        # direnv despejando um parágrafo de `export +AR +AS +CC +CXX +LD +NM +OBJCOPY
        # +RANLIB +NIX_CFLAGS_COMPILE +NIX_HARDENING_ENABLE …` a cada `cd` no repo. Sem o
        # CC isso encurta pro que interessa, e o shell fica mais leve de montar.
        pkgs.mkShellNoCC {
          inherit shellHook;
          buildInputs = enabledPackages ++ [ pkgs.nixd ];
        };
    };
}
