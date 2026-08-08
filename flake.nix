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

    # VS Code do tarball OFICIAL do canal stable, em versão FIXA. Existe porque o nixpkgs
    # não serve: o bump lá é humano/bot e fica 3-14 dias atrás, às vezes PULANDO release
    # (1.125→1.127, 1.127→1.129.1 em jul/26). A causa é estrutural — o auto-updater do VS Code
    # não roda com a store read-only, então a versão é literalmente o que está no lock. NÃO é o
    # Insiders (build de teste diária). `flake = false` porque é tarball, não flake.
    #
    # NOME: chamava-se `vscode-latest` até 05/08/2026, e o nome virou mentira no minuto em
    # que a URL foi fixada — "latest" prometia um acompanhamento automático que não existe
    # mais. `-tarball` diz o que É (e explica o `flake = false`), sem prometer versão.
    #
    # URL VERSIONADA e não `/latest/` — mudou em 05/08/2026, e o motivo foi o CI ficar VERMELHO:
    #   error: mismatch in field 'narHash' of input '…/latest/linux-x64/stable'
    #          lock: sha256-2Fzf… | servido: sha256-PLpT…
    # A causa: `/latest/` é PONTEIRO. Saiu a 1.132.0, o ponteiro andou, e o narHash travado (que
    # era da 1.131.0) deixou de casar. Aqui passava porque o tarball velho já estava na store;
    # em máquina limpa — CI, clone novo, reinstalação — o flake não avaliava mais. Ou seja: o
    # furo na regra 13 não era um risco de 2032, era quebra a cada release do VS Code.
    #
    # Medido antes de trocar (o que prova que a URL versionada resolve): `/1.131.0/` devolve
    # exatamente o `sha256-2Fzf…` que estava no lock, e `/1.132.0/` devolve `sha256-PLpT…` —
    # os dois estáveis em fetches repetidos. Artefato versionado é imutável; ponteiro não é.
    #
    # PREÇO da URL fixa: `nix flake update` não traz versão nova sozinho. Quem paga é o
    # `vscode-bump` (pkgs/vscode-bump.nix) desde 06/08/2026 — consulta a API oficial,
    # reescreve o número DESTA linha e roda `nix flake update vscode-tarball`. Ele é o
    # primeiro passo dos aliases `update`/`upgrade` (home/shell/zsh.nix), então "sempre na
    # última stable" acontece no rebuild, sem edição manual e sem furar a regra 13 (o hash
    # continua travado no lock; o que mudou é QUEM o atualiza). Subir na mão continua
    # possível: editar aqui + `nix flake update vscode-tarball`.
    vscode-tarball = {
      url = "tarball+https://update.code.visualstudio.com/1.132.0/linux-x64/stable";
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

      # Troca só o SRC do vscode pelo tarball do input vscode-tarball, mantendo a RECEITA do
      # unstable — o generic.nix do nixpkgs tem lógica versionada (`versionAtLeast
      # vscodeVersion "1.129.0"`), então patchar receita fresca é o delta mínimo; sobre a
      # receita da 26.05 (era 1.119) o salto de 12 versões passaria por ramos que não existem.
      # Patcha DENTRO de `unstable` (por isso vem depois do overlayUnstable) porque `unstable`
      # é outro import de nixpkgs, que os overlays daqui não alcançam.
      #   version: lido do package.json do próprio tarball. O input já é store path em eval,
      #            então é readFile puro — sem IFD, sem hash duplicado pra manter.
      #   sourceRoot: o fetcher de tarball do flake REMOVE o dir de topo (VSCode-linux-x64),
      #               diferente do fetchurl do nixpkgs (que usa sourceRoot = "").
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

      # Pacotes LOCAIS (fora do nixpkgs), empacotados em ./pkgs e expostos como
      # `pkgs.<nome>`. callPackage injeta as deps automaticamente.
      overlayLocalPkgs = final: _: {
        claude-code-discord-status = final.callPackage ./pkgs/claude-code-discord-status.nix { };
        nxbender = final.callPackage ./pkgs/nxbender.nix { }; # cliente FOSS da VPN SonicWall (FAI)
        vscode-bump = final.callPackage ./pkgs/vscode-bump.nix { }; # bump do vscode-tarball p/ a última stable
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
          specialArgs = { inherit inputs; };
          modules = [
            # `hostPlatform` no lugar do argumento `system` do nixosSystem: o próprio
            # nixpkgs chama aquele de saída "legacy" e o zera no wrapper do flake —
            # «Allow system to be set modularly in nixpkgs.system. We set it to null,
            # to remove the "legacy" entrypoint's non-hermetic default.» (nixpkgs/flake.nix).
            # O default dele é `builtins.currentSystem`, que é IMPURO; declarar como opção
            # de módulo é a forma hermética, e um host cross-compilado só sobrescreve aqui.
            { nixpkgs.hostPlatform = system; }

            # `unstable.*` + pacotes locais (./pkgs) + claude-desktop (flake; overlay
            # em vez de packages.<system> pra buildar contra ESTA base, sem 3º nixpkgs)
            # (o overlayClaudeKeyring vem DEPOIS do upstream: ele reembrulha o pacote dele)
            {
              nixpkgs.overlays = [
                overlayUnstable
                overlayVscodeTarball # DEPOIS do overlayUnstable: patcha o `unstable.vscode` dele
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

      # O que ESTE repo empacota ou reembrulha, exposto peça por peça:
      #   nix build .#nxbender
      # Antes só existiam dentro do overlay, o que os tornava inconstruíveis
      # isoladamente — não dava pra testar um patch sem passar por um rebuild inteiro.
      #
      # O `pkgs` vem do PRÓPRIO host e não de um `import nixpkgs` novo, por dois
      # motivos: é o MESMO objeto que o sistema instala (então o check abaixo não pode
      # divergir do que a máquina recebe — regra 14), e não acrescenta uma 2ª
      # instanciação de nixpkgs à avaliação (o mesmo cuidado do pkgsUnstable acima).
      packages.${system} =
        let
          pkgs = self.nixosConfigurations.nixos-kingston.pkgs;
        in
        {
          inherit (pkgs)
            claude-code-discord-status # ./pkgs — daemon do Rich Presence
            nxbender # ./pkgs — cliente da VPN SonicWall (3 patches sobre o upstream)
            claude-desktop # flake de terceiro + o wrapper de keyring daqui
            vscode-bump # ./pkgs — o build é o shellcheck do script (regra 7)
            ;
          inherit (pkgs.unstable) vscode; # receita do unstable com o SRC do tarball oficial
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
      # E o CI (.github/workflows/nix.yml) virou o TERCEIRO consumidor da mesma
      # definição em 04/08/2026: roda `nix flake check` com `--override-input
      # duo-streak-daemon path:./ci/stub-duo` (o stub dispensa deploy key pro input
      # privado). Ou seja, mexer nos hooks abaixo muda o CI sozinho — não há mais uma
      # segunda lista de linters no workflow.
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
            # Cobre os `.sh` de ./scripts — a regra 7 diz que a lógica mora no build, e
            # o sync-secrets.sh já ganha shellcheck de graça por vir de um
            # writeShellApplication. O owfetch.sh NÃO ganha: ele roda em ash no OpenWrt,
            # não aqui, então nenhuma derivação o embrulha. Sem este hook, o único `.sh`
            # do repo que executa em máquina ALHEIA seria o único sem verificação.
            shellcheck.enable = true;
          };
        };

        # CONSTRÓI o que o repo empacota — a parte que o gate NÃO cobria (04/08/2026).
        # O `nix flake check` constrói o que está em `checks` («the derivations specified
        # by the flake's checks output can be built successfully»), mas de
        # `nixosConfigurations` só exige que o toplevel «must be derivations»: ele
        # AVALIA o host e para aí. Medido antes desta linha: o check imprimia
        # "running 1 flake checks…" — a única coisa construída era o pre-commit.
        #
        # A diferença importa porque o frágil aqui não é avaliação, é EMPACOTAMENTO: os
        # 3 patches do nxbender, o `sourceRoot = "source"` do vscode e o wrapProgram
        # sobre o .deb do claude-desktop são suposições sobre árvore de terceiro. Nenhuma
        # quebra no eval — quebram no build, DEPOIS do `nix flake update`. E `upgrade` é
        # `update && nh os switch`, então a quebra caía no meio do switch.
        #
        # linkFarm e não symlinkJoin: farm não funde diretórios, então dois pacotes com
        # o mesmo `bin/` não colidem. O derivado é descartável — o valor é o build.
        #
        # DE PROPÓSITO não é o `system.build.toplevel`: construir o sistema inteiro no
        # runner do GitHub arrastaria o quickshell (Qt/C++). Aqui só entram os pacotes
        # que o repo controla, que é onde os patches podem apodrecer.
        pacotes = nixpkgs.legacyPackages.${system}.linkFarm "checks-pacotes-do-repo" (
          nixpkgs.lib.mapAttrsToList (name: path: { inherit name path; }) self.packages.${system}
        );
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
