# ═══════════════════════════════════════════════════════════════════════════
# SISTEMA — config COMUM a todos os hosts (machine-agnostic).
# O específico de cada máquina (hostname, hardware-configuration.nix, discos,
# stateVersion) vive em hosts/<host>.nix. Cresce por tema: mova assuntos grandes
# pra system/<tema>.nix e importe aqui.
# ═══════════════════════════════════════════════════════════════════════════
{ config, pkgs, inputs, ... }:

{
  imports = [
    ./restic.nix # backup cifrado do estado do usuário (repo no HDD por ora)
  ];

  # ── Segredos (sops-nix) ───────────────────────────────────────────────────
  # Segredos criptografados em secrets/secrets.yaml (versionados no git, mas
  # ilegíveis sem a chave). Decriptados em runtime pra /run/secrets*. A chave
  # privada age (/var/lib/sops-nix/key.txt) fica FORA do git — é o que se leva
  # no cutover. Editar: nix shell nixpkgs#sops -c sops secrets/secrets.yaml
  sops = {
    defaultSopsFile = ../secrets/secrets.yaml;
    age.keyFile = "/var/lib/sops-nix/key.txt";
    secrets.v1cferr_password_hash.neededForUsers = true; # senha: precisa cedo
    secrets.cloudflare_ddns_token = { };
    secrets.restic_password = { }; # senha do repo restic (backup do estado)
  };

  # ── Boot (UEFI, systemd-boot) ──────────────────────────────────────────────
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 10; # ESP não enche de gerações

  # ── Rede ───────────────────────────────────────────────────────────────────
  networking.networkmanager.enable = true;

  # ── Nix / flakes ─────────────────────────────────────────────────────────
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true; # dedup por hardlink na /nix/store
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d"; # a /nix/store não cresce pra sempre
  };
  # GC reativo por espaço (complementa o timer acima): se durante um build o
  # espaço livre cair abaixo de min-free, coleta lixo até liberar max-free e
  # segue o build. Evita "no space left" no meio de um rebuild grande.
  # Valores = default consolidado da comunidade; suba min-free se um dia faltar.
  nix.settings.min-free = 1024 * 1024 * 1024; # 1 GiB
  nix.settings.max-free = 5 * 1024 * 1024 * 1024; # 5 GiB
  nixpkgs.config.allowUnfree = true; # google-chrome, vscode, etc.

  # ── Compat com binários FHS (nix-ld) ──────────────────────────────────────
  # NixOS não roda binários dinâmicos "genéricos" (que buscam /lib64/ld-linux…).
  # O nix-ld provê esse loader → faz funcionar VS Code Remote-SSH (vscode-server),
  # wheels Python/CUDA (uv pip install torch), etc. (item "dia 1" do README).
  programs.nix-ld.enable = true;

  # ── Local / idioma ─────────────────────────────────────────────────────────
  time.timeZone = "America/Sao_Paulo";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "br-abnt2"; # teclado no TTY (a GUI é no bloco Desktop)

  # ── Hardware (mesma máquina física em todos os hosts: MOBO EX-B560M-V5) ─────
  hardware.cpu.intel.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;
  zramSwap.enable = true; # swap comprimido na RAM

  # ── GPU: NVIDIA RTX 3050 (Ampere) — driver proprietário ──────────────────────
  # nouveau em Ampere não faz reclocking (fica lento) e não tem CUDA. O driver
  # proprietário com módulos ABERTOS é o caminho recomendado p/ Turing+ e o que
  # faz Hyprland/Wayland + Vulkan + CUDA funcionarem de verdade.
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true; # OpenGL/Vulkan (ex-hardware.opengl)
  hardware.nvidia = {
    modesetting.enable = true; # obrigatório p/ Wayland/Hyprland
    open = true; # módulos abertos (Ampere suporta; recomendado)
    nvidiaSettings = true; # app gráfico nvidia-settings
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # ── Áudio: PipeWire (substitui PulseAudio/JACK) ─────────────────────────────
  # Stack de som padrão no NixOS moderno + Wayland. O WirePlumber (session
  # manager) vem junto e cuida do roteamento — inclusive de áudio Bluetooth
  # (A2DP/HFP), sem precisar de módulo extra como no PulseAudio antigo. O rtkit
  # dá prioridade de tempo-real ao servidor (evita xruns/estalos).
  # Controle: `wpctl` (CLI, vem no wireplumber), `pavucontrol` (GUI) e, nos
  # keybinds do Hyprland, `pamixer` (volume) + `playerctl` (play/pause/next).
  security.rtkit.enable = true;
  services.pulseaudio.enable = false; # o PipeWire assume o lugar do PulseAudio
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true; # apps 32-bit (jogos/Wine) tocam som
    pulse.enable = true; # compat: apps que falam PulseAudio (a maioria)
    jack.enable = true; # compat: apps pro-audio que falam JACK
    wireplumber.enable = true;
  };

  # ── Bluetooth ───────────────────────────────────────────────────────────────
  # BlueZ (stack) + liga o adaptador no boot. blueman = applet/GUI de bandeja
  # pra parear/gerenciar em desktop sem DE (Hyprland). Áudio BT sai via PipeWire.
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;

  # ── Desktop: Hyprland (Wayland) ─────────────────────────────────────────────
  # Compositor Wayland. LightDM (greeter X11) lança a sessão Hyprland; Xwayland
  # cobre apps X11. Atenção: na sessão Wayland o teclado e os monitores NÃO vêm
  # do xkb/xrandr do sistema — são config do Hyprland (~/.config/hypr/hyprland.conf:
  # input.kb_layout p/ ABNT2 e linhas `monitor=` p/ o arranjo/primário).
  services.xserver.enable = true; # habilita LightDM (greeter X11) + Xwayland
  services.xserver.displayManager.lightdm.enable = true;
  programs.hyprland.enable = true;
  # xkb do sistema: cobre o greeter (LightDM/X11) e apps Xwayland.
  services.xserver.xkb = {
    layout = "br"; # variante padrão do "br" = ABNT2
    variant = "";
  };
  # Apps Electron/Chromium (vscode, spotify, chrome, claude-code) rodam nativos
  # em Wayland em vez de Xwayland.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # ── Dark mode: portal p/ o color-scheme (config do tema vive em home/theme.nix) ─
  # O programs.hyprland já habilita o xdg.portal (+ portal-hyprland p/ screencast).
  # O portal-gtk é quem serve org.freedesktop.appearance (color-scheme) → é assim
  # que apps Electron/Chromium (vscode, chrome, spotify) escurecem junto do sistema.
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

  # ── Keyring / Secret Service (gnome-keyring) ──────────────────────────────
  # Provê o org.freedesktop.secrets — onde apps guardam segredos CIFRADOS em vez
  # de texto plano (git via libsecret, NetworkManager, navegadores, etc.).
  # Destranca automaticamente no login do LightDM (PAM, com a senha do usuário).
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.lightdm.enableGnomeKeyring = true;
  programs.seahorse.enable = true; # GUI "Senhas e Chaves" pra gerenciar

  # ── Fontes e tipografia ─────────────────────────────────────────────────────
  fonts = {
    packages = with pkgs; [ nerd-fonts.jetbrains-mono ];
    fontconfig = {
      enable = true;
      # Estética "laboratório": JetBrains Mono também em menus/navegador.
      defaultFonts = {
        monospace = [ "JetBrainsMono Nerd Font" ];
        sansSerif = [ "JetBrainsMono Nerd Font" ];
        serif = [ "JetBrainsMono Nerd Font" ];
      };
    };
  };

  # ── Usuário (capacidade declarada; senha/chaves = "quem sou eu") ────────────
  # Hash da senha via sops (fora do git). Chaves públicas SSH são públicas — ok.
  users.users.v1cferr = {
    isNormalUser = true;
    description = "Victor";
    extraGroups = [ "wheel" "networkmanager" ];
    hashedPasswordFile = config.sops.secrets.v1cferr_password_hash.path;
    openssh.authorizedKeys.keys = [
      # chave que entra no Arch hoje (~/.ssh/authorized_keys)
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKPvFX6AAslYtCXeUnNmSIKL4GESHvgO+irlnJ5+2ltD dev.victorferreira@gmail.com"
      # chave local do Arch/Kingston — pra hop Arch -> NixOS
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINRHYth5yugzhdulstjLPJAqHuzXE6j/EVl7dHcWKIUI dev.victorferreira@gmail.com"
    ];
  };
  security.sudo.wheelNeedsPassword = true;

  # ── SSH (espelha o Arch: porta 2222, root off, senha como fallback) ─────────
  services.openssh = {
    enable = true;
    ports = [ 2222 ];
    openFirewall = true; # abre a 2222 no firewall
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = false;
    };
  };

  # ── Nunca suspender ─────────────────────────────────────────────────────
  # É um desktop de acesso remoto (SSH). Se suspender, o SSH cai e você não
  # alcança de outro PC. Desativa todos os alvos de sono.
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

  # ── fail2ban — protege o SSH exposto na internet ─────────────────────────
  # A 2222 fica aberta ao mundo (port-forward 2222 no OpenWrt) COM senha
  # habilitada → fail2ban é obrigatório. Espelha o jail do Arch: bane após 4
  # falhas em 10min, por 1h; nunca bane a LAN nem o loopback.
  services.fail2ban = {
    enable = true;
    bantime = "1h";
    ignoreIP = [ "127.0.0.1/8" "::1" "192.168.1.0/24" ];
    jails.sshd.settings = {
      enabled = true;
      port = 2222;
      backend = "systemd"; # sshd loga no journald
      maxretry = 4;
      findtime = "10m";
    };
  };

  # ── DNS dinâmico (Cloudflare) ─────────────────────────────────────────────
  # Mantém ssh.v1cferr.dev apontando pro IP público atual (que muda) → permite
  # `ssh …@ssh.v1cferr.dev` de qualquer lugar, sem VPN. Token FORA do git
  # (via sops). proxied=false: registro DNS-only (cinza) — SSH não passa pelo
  # proxy HTTP da Cloudflare.
  services.cloudflare-dyndns = {
    enable = true;
    apiTokenFile = config.sops.secrets.cloudflare_ddns_token.path;
    domains = [ "ssh.v1cferr.dev" ];
    proxied = false;
    ipv4 = true;
    ipv6 = false;
  };

  # ── Pacotes (LISTA ÚNICA) ────────────────────────────────────────────────
  # Máquina de um usuário só → não faz sentido separar system vs user. TODO
  # pacote instalado vive aqui. O home-manager (home/) NÃO instala pacote — ele
  # só CONFIGURA (dotfiles/settings).
  #
  # `pkgs.foo`          → versão da BASE estável (26.05). Use por padrão.
  # `pkgs.unstable.foo` → versão BLEEDING-EDGE (canal unstable). Só o que você
  #                       quiser sempre na última. Overlay definido no flake.nix.
  environment.systemPackages = with pkgs; [
    # ── base estável ──
    git
    gh # GitHub CLI (auth/push via HTTPS + token)
    vim
    htop
    openssl # gerar senhas/chaves (rand), TLS, etc.
    kitty # terminal do Hyprland default (SUPER+Q)
    wofi # launcher do Hyprland default (SUPER+R)
    waybar # barra de status (workspaces + relógio); config em home/waybar.nix
    pavucontrol # GUI de mixer/dispositivos (PipeWire via compat PulseAudio)
    pamixer # controle de volume via CLI (pros keybinds de mídia do Hyprland)
    playerctl # play/pause/next via CLI (teclas de mídia)
    hypridle # daemon de ociosidade do Hyprland (apaga os monitores; config em home/hypr.nix)
    gnome-themes-extra # tema GTK Adwaita-dark (usado pelo home/theme.nix)
    bibata-cursors # tema de cursor Bibata-Modern-Ice (config no home/)
    librewolf
    google-chrome
    inputs.zen-browser.packages.${pkgs.system}.default # Zen (flake; ver flake.nix)
    vscode
    spotify # unfree (ok: allowUnfree acima)
    # whatsapp  # (estava comentado na config original)
    unzip

    # ── Gerenciador de arquivos: Dolphin (KDE) ──
    # GUI mais completo: split view, abas, terminal embutido, previews. Os pacotes
    # extras é que ligam os recursos: kio-extras = SFTP/SMB/MTP (celular via USB);
    # thumbnailers = miniaturas de imagem/pdf/vídeo. Lixeira (trash:/) é nativa.
    kdePackages.dolphin
    kdePackages.kio-extras
    kdePackages.kdegraphics-thumbnailers
    kdePackages.ffmpegthumbs

    # ── bleeding-edge (escolhidos a dedo) ──
    unstable.fastfetch
    unstable.claude-code
  ];
}
