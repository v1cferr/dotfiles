# SYSTEM PACKAGES: rescue, diagnosis and whatever root or a service needs. USER apps are home/'s
# (rule 4). `pkgs.foo` = the stable base; `pkgs.unstable.foo` = bleeding edge (see the overlay).
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # ── the stable base ──
    git
    vim
    htop
    dmidecode
    btop # a resource monitor (CPU/mem/disk/network) with a rich TUI; htop on steroids
    tree # it lists the directory tree in the terminal
    gdu # a TUI disk usage analyzer (Go), ~5x faster than ncdu on a big disk (`sudo gdu -x /`)
    kdePackages.filelight # a GUI disk usage analyzer (KDE, a sunburst chart); it integrates with Dolphin/Kvantum
    # nix-tree answers "which PACKAGE weighs the most", which is a different question from gdu's.
    nix-tree # it browses a derivation's closure by SIZE (`nix-tree /run/current-system`)
    jq # it processes/queries JSON in the terminal (used in the secrets flow with bw)
    openssl # generating passwords/keys (rand), TLS, and so on
    python3 # the Python interpreter (running scripts; per-project libs live in uv/venv)
    uv # a fast Python manager (venv/deps/pythons); its pythons run through nix-ld
    unzip # it extracts .zip files (a base utility)
    # RESCUE: the restic module only generates wrappers PER REPO, so the Arch archive would need a
    # `nix shell` to read. A backup that requires gymnastics to read is half a backup.
    restic # the restic client, to inspect/restore ANY repo (see docs/history/)

    # ── GPU: monitoring (Arc B580) ──
    # The benchmarks left after the Arc was validated; only the day-to-day monitors remain.
    nvtopPackages.intel # a live GPU monitor (util/clock/VRAM/temp), Intel
    intel-gpu-tools # intel_gpu_top: the Intel driver's engines/frequencies
    # It answers "does Hyprland still serve wlr-gamma-control?" without guessing (08/08/2026).
    wayland-utils # wayland-info
  ];
}
