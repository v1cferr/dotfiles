# ═══════════════════════════════════════════════════════════════════════════
# REDE & ACESSO REMOTO — NetworkManager, SSH (exposto), fail2ban, DNS dinâmico
# e "nunca suspender". Tema: esta é uma máquina de acesso remoto por SSH.
# ═══════════════════════════════════════════════════════════════════════════
{ config, ... }:

{
  # ── Rede ───────────────────────────────────────────────────────────────────
  networking.networkmanager.enable = true;

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
}
