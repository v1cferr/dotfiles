# ═══════════════════════════════════════════════════════════════════════════
# SISTEMA (root) — host nixos-seagate (HDD Seagate ST9320423AS).
# Tudo que é do sistema vive aqui. Cresce por tema: quando um assunto ficar
# grande, mova-o pra system/<tema>.nix e adicione em `imports` abaixo.
# ═══════════════════════════════════════════════════════════════════════════
{ config, pkgs, ... }:

{
  imports = [
    ../hardware-configuration.nix # gerado pela máquina — não editar
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
  };

  # ── Boot (UEFI, systemd-boot no ESP DESTE disco) ───────────────────────────
  # Não mexe no boot do Arch/Kingston nem do Windows.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 10; # ESP não enche de gerações

  # ── Rede ───────────────────────────────────────────────────────────────────
  networking.hostName = "nixos-seagate";
  networking.networkmanager.enable = true;

  # ── Nix / flakes ─────────────────────────────────────────────────────────
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true; # dedup por hardlink na /nix/store
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d"; # a /nix/store não cresce pra sempre
  };
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

  # ── Hardware desta máquina ──────────────────────────────────────────────────
  hardware.cpu.intel.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;
  zramSwap.enable = true; # HDD é lento → swap comprimido na RAM

  # ── Discos extras ───────────────────────────────────────────────────────
  # Kingston (nvme) = Arch de PRODUÇÃO. README: "não tocar até o cutover".
  # Monto SÓ-LEITURA (ro+noload = zero escrita garantida) só pra ler/copiar os
  # dotfiles. nofail + automount: não trava o boot e monta no 1º acesso; se o
  # disco sair, o sistema sobe normal. UUID (estável; nomes nvmeX embaralham).
  fileSystems."/mnt/kingston-arch" = {
    device = "/dev/disk/by-uuid/d98ec566-6ec2-4371-8048-d3a4f02b2cbb";
    fsType = "ext4";
    options = [ "ro" "noload" "nofail" "x-systemd.automount" ];
  };

  # ── Desktop: GNOME sobre X11 ────────────────────────────────────────────────
  # (O rice Hyprland+Quickshell entra numa fase futura — ver README.)
  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  # Teclado no LOGIN (GDM). A sessão do usuário no GNOME/Wayland usa a input
  # source declarada em home/gnome.nix — as duas coisas são separadas.
  services.xserver.xkb = {
    layout = "br"; # variante padrão do "br" = ABNT2
    variant = "";
  };

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
  # Hash da senha vive FORA do git, em arquivo root-only. NUNCA rastrear hash em
  # repo público (o antigo vazou → rotacionar). Gerar o arquivo:
  #   sudo sh -c 'umask 077; mkdir -p /etc/secrets; \
  #     nix run nixpkgs#mkpasswd -- -m sha-512 > /etc/secrets/v1cferr.hash'
  # Futuro: migrar pra sops-nix (regra #4 do README).
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
  # (arquivo root-only). proxied=false: registro DNS-only (cinza) — SSH não
  # passa pelo proxy HTTP da Cloudflare.
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
    kitty
    librewolf
    google-chrome
    vscode
    # whatsapp  # (estava comentado na config original)

    # ── bleeding-edge (escolhidos a dedo) ──
    unstable.fastfetch
    unstable.claude-code
  ];

  # Fixado na 1ª instalação — NUNCA mudar depois (não é "versão do sistema").
  system.stateVersion = "26.05";
}
