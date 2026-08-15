# ═══════════════════════════════════════════════════════════════════════════
# ~/OneDrive — o OneDrive INSTITUCIONAL (victor.ferreira@fai.ufscar.br) montado
# como pasta local via onedriver (FUSE, on-demand) → aparece no Dolphin como
# pasta normal, igual ao ~/Drive e ao ~/FAI-workstation, com bookmark em
# home/apps/dolphin.nix.
#
# ── "CLIENTE OFICIAL" DA MICROSOFT NÃO EXISTE (e não é isso que o tenant vê) ─
# A Microsoft nunca publicou cliente de OneDrive pra Linux — só Windows, macOS,
# iOS e Android. O que dá pra ser "oficial" aqui é o CAMINHO: API oficial
# (Microsoft Graph) + login oficial (Entra ID / OAuth2 authorization code), que é
# exatamente o que o onedriver faz. Nada de WebDAV legado, scraping ou senha de
# app.
#
# E o tenant não aprova "programas": ele aprova APP REGISTRATION (client ID). Do
# ponto de vista do Entra da FAI, o que pede consentimento é um app com
# `clientID` — o binário que fala com ele é irrelevante. Por isso `clientId` e
# `tenant` são OPÇÃO aqui e não literal enterrado no meio do código: se o TI da
# FAI exigir um app registrado DENTRO do tenant (política de consentimento que
# bloqueia app de terceiro), troca-se o `clientId` e nada mais muda.
#
# ── POR QUE MOUNT E NÃO SYNC (abraunegg/onedrive, rclone bisync) ────────────
# Mesma decisão do ~/Drive (home/services/drive-mount.nix), e aqui pesa mais: é
# conta INSTITUCIONAL. Sync PROPAGA delete — um apagão local viraria apagão no
# OneDrive da FAI, que não é meu pra recuperar. Num mount cada operação é
# explícita e única. O que se perde é acesso OFFLINE (o onedriver serve do cache
# o que já foi aberto; o resto fica indisponível sem rede).
#
# ── ISTO NÃO É BACKUP ──────────────────────────────────────────────────────
# É uma JANELA pro OneDrive: apagar aqui apaga lá. Backup é o restic
# (system/services/restic.nix) — regra 6.
#
# ── PEGADINHAS ─────────────────────────────────────────────────────────────
# • O MOUNTPOINT TEM QUE ESTAR VAZIO: o onedriver recusa com "Mountpoint must be
#   empty" (cmd/onedriver/main.go). Mount não subiu? `ls -a ~/OneDrive` ANTES de
#   suspeitar de rede — foi exatamente o que travou o primeiro start do ~/Drive.
# • O onedriver ESCREVE um `.xdg-volume-info` na RAIZ do OneDrive no primeiro
#   mount (é o rótulo/ícone do volume). Arquivo de 100 bytes, mas ele aparece pra
#   quem abrir a pasta pelo Office/web.
# • Arquivo grande: o onedriver carrega o arquivo em memória ao abrir. Vídeo de
#   vários GB é sofrimento — pra esses, baixar pelo navegador.
# • SharePoint / pastas COMPARTILHADAS não são suportados pelo onedriver — só o
#   "meu" OneDrive. Se o que se quer for biblioteca de equipe da FAI, este módulo
#   não resolve (aí o caminho é rclone com backend `onedrive`, que fala SharePoint).
# ═══════════════════════════════════════════════════════════════════════════
{
  config,
  osConfig,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.my.onedrive;

  # Nome da pasta de cache: o onedriver escapa o caminho ABSOLUTO do mountpoint do
  # mesmo jeito que o systemd (`systemd-escape --path`, via unit.UnitNamePathEscape
  # em cmd/onedriver/main.go). Pra caminho simples como este, escapar é só tirar a
  # "/" da frente e trocar as outras por "-". ⚠️ Se o mountpoint ganhar ponto,
  # espaço ou acento, o systemd escaparia como \xNN e esta conta erraria — conferir
  # com `systemd-escape --path <novo>` antes de mudar `local`.
  cacheName = builtins.replaceStrings [ "/" ] [ "-" ] (lib.removePrefix "/" cfg.local);

  # Onde o onedriver guarda o token OAuth. É ESTADO (regra 6): não se declara.
  # E nem vai pro restic — /home/v1cferr/.cache é excluído do backup
  # (system/services/restic.nix). Perder isto custa refazer o login, nada mais;
  # mesmo critério do token do rclone no ~/Drive.
  authTokens = "${config.xdg.cacheHome}/onedriver/${cacheName}/auth_tokens.json";
in
{
  options.my.onedrive = {
    local = lib.mkOption {
      type = lib.types.str;
      default = "/home/v1cferr/OneDrive";
      description = "Ponto de montagem. Lido também pelo bookmark do Dolphin (SSOT, regra 11).";
    };

    tenant = lib.mkOption {
      type = lib.types.str;
      default = "80241bb1-cb3b-4da2-98ae-3029430fdbcd";
      description = ''
        Tenant do Entra ID (o `common` do onedriver trocado pelo tenant da FAI).
        Descoberto por
        `curl -s https://login.microsoftonline.com/fai.ufscar.br/v2.0/.well-known/openid-configuration`.
        Fixar o tenant em vez de `common` faz o login recusar conta pessoal cedo,
        com erro legível, em vez de autenticar e falhar depois no Graph.
      '';
    };

    clientId = lib.mkOption {
      type = lib.types.str;
      default = "3470c3fa-bc10-45ab-a0a9-2d30836485d1";
      description = ''
        App registration que pede o consentimento. O default é o app público do
        onedriver (multi-tenant, resolve no tenant da FAI).

        ⚠️⚠️ MEDIDO EM 15/08/2026, E O VEREDITO É "SÓ O TI RESOLVE": o login
        interativo bateu em "Need admin approval". A causa NÃO é a permissão em
        si — `Files.ReadWrite.All` é `type=User` no catálogo do Graph
        (`AdminConsentRequired = No`), usuário comum poderia consentir. O que
        barra é o cruzamento de duas coisas DESTE tenant:
          • a política é `ManagePermissionGrantsForSelf.microsoft-user-default-low`
            (`az rest --url ".../v1.0/policies/authorizationPolicy"`), que só deixa
            o usuário consentir quando TODAS as permissões pedidas estão
            classificadas como low-impact;
          • e as classificadas aqui são só as CINCO de fábrica — `User.Read`,
            `openid`, `email`, `profile`, `offline_access` (`az rest --url
            ".../servicePrincipals(appId='00000003-0000-0000-c000-000000000000')/delegatedPermissionClassifications"`).
        O onedriver pede `user.read files.readwrite.all offline_access` (lido na
        própria URL de auth, com `onedriver -a -n`), então o `files.readwrite.all`
        fica de fora da lista e o consentimento de usuário morre ali.

        ⚠️ TROCAR ESTA LINHA NÃO RESOLVE SOZINHO — e essa era a saída óbvia.
        Registrar um app DENTRO do tenant (dá: `allowedToCreateApps` está `true`)
        satisfaz o "apps registered in your tenant" da política, mas não
        CLASSIFICA permissão nenhuma: o `files.readwrite.all` continua fora e a
        tela de aprovação volta igual. E consentir por conta própria também não é
        opção — `/me/memberOf` devolve só grupos, nenhum papel de diretório.

        O QUE DESTRAVA (as duas passam pelo TI da FAI): admin consent no app — e
        aí um app registrado no tenant AJUDA, porque é um app que eles veem e
        controlam, em vez de um multi-tenant de terceiro —, ou classificar a
        permissão como low-impact. Se for pedir, `Files.ReadWrite` (só o drive do
        usuário) é pedido bem mais fácil de aprovar que o `.All`, mas exige patch
        no onedriver, que enterra o scope no binário.

        ⚠️ App próprio, quando chegar a hora: tem que ser PÚBLICO (sem client
        secret — o onedriver não manda nenhum) e o redirect TEM que ser exatamente
        `https://login.live.com/oauth20_desktop.srf` como "Mobile and desktop
        applications". Esse literal está HARDCODED em C na janela de login
        (`auth_complete_url` em fs/graph/oauth2_gtk.c): com outro redirect o popup
        autentica e simplesmente NUNCA FECHA, porque ninguém captura o `code`.
        Com outro redirect só funciona o fluxo `-n` (colar a URL no terminal).
      '';
    };
  };

  config = lib.mkIf osConfig.my.services.onedrive-mount {
    home.packages = [ pkgs.onedriver ]; # regra 4: app de usuário mora no home/

    # ⚠️ REGRA 14 — este arquivo tem UM dono, e é o nix. O `onedriver-launcher`
    # (GUI que vem no mesmo pacote) também grava aqui: usar a GUI pra adicionar
    # conta vai falhar com "permission denied", porque isto é symlink pro store.
    # É de propósito — a conta e o mountpoint são declarados, não clicados.
    xdg.configFile."onedriver/config.yml".text = ''
      log: info
      cacheDir: ${config.xdg.cacheHome}/onedriver
      auth:
        clientID: "${cfg.clientId}"
        codeURL: "https://login.microsoftonline.com/${cfg.tenant}/oauth2/v2.0/authorize"
        tokenURL: "https://login.microsoftonline.com/${cfg.tenant}/oauth2/v2.0/token"
        redirectURL: "https://login.live.com/oauth20_desktop.srf"
    '';

    systemd.user.services.onedrive-mount = {
      Unit = {
        Description = "OneDrive da FAI montado em ${cfg.local} (onedriver)";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
        # No login a rede demora alguns segundos; sem isto o systemd desistiria
        # após 5 falhas rápidas (StartLimit). Mesmo motivo do drive-mount.
        StartLimitIntervalSec = 0;
      };

      Service = {
        # O LOGIN É INTERATIVO e roda UMA vez na mão:
        #     onedriver --auth-only ~/OneDrive
        # (abre o navegador embutido; `-n` faz por URL no terminal). Sem token o
        # onedriver tentaria ler o código do stdin — que num serviço não existe —
        # e morreria em loop de restart. `ExecCondition` deixa a unit INERTE
        # ("condition failed", não "failed") até o token existir: mesma regra do
        # resto do repo, onde módulo sem segredo ainda não sincronizado não derruba
        # o switch. Falha de condição = exit 1-254, que é o que o `test` devolve.
        ExecCondition = "${pkgs.coreutils}/bin/test -f ${authTokens}";

        ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${cfg.local}";
        ExecStart = "${pkgs.onedriver}/bin/onedriver ${cfg.local}";

        # Rede de segurança pro mount pendurado (o `-` ignora falha quando já está
        # desmontado). Tem que ser o WRAPPER setuid do NixOS — o fusermount3 do
        # pacote não tem privilégio. Igual ao ~/Drive.
        ExecStopPost = "-/run/wrappers/bin/fusermount3 -uz ${cfg.local}";

        # `on-abnormal` (e não `on-failure`) de propósito, seguindo o unit do
        # upstream: o onedriver sai com 1 quando o erro é DEFINITIVO (token
        # recusado, mountpoint sujo) — reiniciar isso é loop infinito escondendo o
        # motivo. Sinal/timeout/exit 2 reinicia; queda de rede ele trata sozinho
        # (fica read-only até voltar).
        Restart = "on-abnormal";
        RestartSec = 10;
        RestartForceExitStatus = 2;
      };

      Install.WantedBy = [ "default.target" ];
    };
  };
}
