# SYSTEM PACKAGES (root level) ────────────────────────────────────────────────
# SYSTEM-LEVEL tools only: rescue/base, diagnosis and whatever root/the services need. USER apps
# and CLIs live in home/ (rule 4): programs.* when there is a module, otherwise home.packages
# grouped by category (see home/apps, home/shell).
#
# `pkgs.foo`          -> the version from the stable BASE (26.05). Use this by default.
# `pkgs.unstable.foo` -> the BLEEDING-EDGE version (the unstable channel). Only for what you want
#                        always on the latest. The overlay is defined in flake.nix.
# ═══════════════════════════════════════════════════════════════════════════
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
    # gdu/filelight answer "which FOLDER weighs the most"; this one answers "which PACKAGE weighs
    # the most", which is another question: it shows the closure sorted by size and what each
    # dependency drags in. It is how we measured that xembedsniproxy cost 429 MiB of qtwebengine
    # (30/07).
    nix-tree # it browses a derivation's closure by SIZE (`nix-tree /run/current-system`)
    jq # it processes/queries JSON in the terminal (used in the secrets flow with bw)
    openssl # generating passwords/keys (rand), TLS, and so on
    python3 # the Python interpreter (running scripts; per-project libs live in uv/venv)
    uv # a fast Python manager (venv/deps/pythons); its pythons run through nix-ld
    unzip # it extracts .zip files (a base utility)
    # RESCUE (criterion 3 in the README): the services.restic module only generates wrappers PER
    # REPO (`restic-home-gdrive`), so a repo with no service, like the Arch archive, was
    # unreachable without a `nix shell`. A backup that requires gymnastics to read is half a
    # backup.
    restic # the restic client, to inspect/restore ANY repo (see docs/history/)

    # ── GPU: monitoring (Arc B580) ──
    # The benchmarks (vulkan-tools/mesa-demos/glmark2/vkmark/unigine/clpeak) were removed after
    # validating the Arc; they were one-offs. Only the day-to-day monitors are left.
    nvtopPackages.intel # a live GPU monitor (util/clock/VRAM/temp), Intel
    intel-gpu-tools # intel_gpu_top: the Intel driver's engines/frequencies
    # It lists the Wayland protocols the compositor exposes and what each output supports.
    # It came in on 08/08/2026 because the question "does Hyprland still serve
    # wlr-gamma-control?" could not be answered without guessing, and a guess becomes a wrong
    # comment in the repo.
    wayland-utils # wayland-info
  ];
}
