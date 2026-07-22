# ═══════════════════════════════════════════════════════════════════════════
# NÚCLEO — Nix/flakes, nixpkgs (unfree/inseguros), nix-ld e locale/idioma.
# ═══════════════════════════════════════════════════════════════════════════
{ ... }:

{
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
  # bitwarden-desktop (Electron) trava no Electron 39 (EOL). Nenhum canal migrou
  # ainda; liberamos SÓ esta versão. Ao bumpar o Bitwarden, revisar/remover isto.
  nixpkgs.config.permittedInsecurePackages = [ "electron-39.8.10" ];

  # ── Compat com binários FHS (nix-ld) ──────────────────────────────────────
  # NixOS não roda binários dinâmicos "genéricos" (que buscam /lib64/ld-linux…).
  # O nix-ld provê esse loader → faz funcionar VS Code Remote-SSH (vscode-server),
  # wheels Python/CUDA (uv pip install torch), etc. (item "dia 1" do README).
  programs.nix-ld.enable = true;

  # ── Local / idioma ─────────────────────────────────────────────────────────
  time.timeZone = "America/Sao_Paulo";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "br-abnt2"; # teclado no TTY (a GUI é no desktop.nix)
}
