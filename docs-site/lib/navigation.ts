// THE NAV, and it is the ONLY topic layer: docs/ stays grouped the way the repo needs it, and the
// reader still gets a manual, because the two are decoupled (rule 20): docs/notes/repo/site.md
//
// It carried over from the MkDocs nav unchanged. `lib/page-tree.ts` is what refuses to build
// when this list and docs/ stop agreeing, which is the guarantee `--strict` used to give.

/** A page. `doc` is the path under docs/; with no `title` the page's own H1 names it. */
export interface NavPage {
  title?: string;
  doc: string;
}

/** A group in the sidebar. A `doc` with no title as its first item becomes the group's own page. */
export interface NavSection {
  section: string;
  items: NavItem[];
}

export type NavItem = NavPage | NavSection;

export const navigation: NavItem[] = [
  { title: "Home", doc: "README.md" },
  { title: "Rules", doc: "rules.md" },
  { title: "How the notes work", doc: "notes/README.md" },
  {
    section: "Boot and storage",
    items: [
      { title: "Boot", doc: "notes/boot-and-storage/boot.md" },
      { title: "Disko", doc: "notes/boot-and-storage/disko.md" },
      { title: "Btrfs", doc: "notes/boot-and-storage/btrfs.md" },
      { title: "btrbk", doc: "notes/boot-and-storage/btrbk.md" },
      { title: "Restic", doc: "notes/boot-and-storage/restic.md" },
      { title: "Arch legacy", doc: "notes/boot-and-storage/arch-legacy.md" },
      { title: "Disk hygiene", doc: "notes/boot-and-storage/disk-hygiene.md" },
      { title: "Disk insight", doc: "notes/boot-and-storage/disk-insight.md" },
      { title: "Games disk", doc: "notes/boot-and-storage/games-disk.md" },
      { title: "Shutdown", doc: "notes/boot-and-storage/shutdown.md" },
    ],
  },
  {
    section: "Hardware",
    items: [
      { title: "GPU", doc: "notes/hardware/gpu.md" },
      { title: "GPU RGB", doc: "notes/hardware/gpu-rgb.md" },
      { title: "Monitors", doc: "notes/hardware/monitors.md" },
      { title: "Fonts", doc: "notes/hardware/fonts.md" },
      { title: "Mouse", doc: "notes/hardware/mouse.md" },
      { title: "Razer", doc: "notes/hardware/razer.md" },
      { title: "OOM", doc: "notes/hardware/oom.md" },
      { title: "Webcam", doc: "notes/hardware/webcam.md" },
    ],
  },
  {
    section: "Network",
    items: [
      { title: "Network", doc: "notes/network/network.md" },
      { title: "VPN", doc: "notes/network/vpn.md" },
      { title: "SSH", doc: "notes/network/ssh.md" },
      { title: "Sunshine", doc: "notes/network/sunshine.md" },
      { title: "Caddy", doc: "notes/network/caddy.md" },
      { title: "Tunnel", doc: "notes/network/tunnel.md" },
      { title: "FAI workstation", doc: "notes/network/fai-workstation.md" },
    ],
  },
  {
    section: "Desktop",
    items: [
      { title: "Desktop", doc: "notes/desktop/desktop.md" },
      { title: "Hyprland", doc: "notes/desktop/hypr.md" },
      { title: "Keybinds", doc: "notes/desktop/keybinds.md" },
      { title: "Quickshell", doc: "notes/desktop/quickshell.md" },
      { title: "Bar", doc: "notes/desktop/bar.md" },
      { title: "Lockscreen", doc: "notes/desktop/lockscreen.md" },
      { title: "Weather", doc: "notes/desktop/weather.md" },
      { title: "Theme", doc: "notes/desktop/theme.md" },
      { title: "Autostart", doc: "notes/desktop/autostart.md" },
      { title: "hyprsunset", doc: "notes/desktop/hyprsunset.md" },
      { title: "Backlight", doc: "notes/desktop/backlight.md" },
      { title: "Desktop plumbing", doc: "notes/desktop/desktop-plumbing.md" },
    ],
  },
  {
    section: "Apps",
    items: [
      { title: "Dolphin", doc: "notes/apps/dolphin.md" },
      { title: "Dropbox", doc: "notes/apps/dropbox.md" },
      { title: "VS Code", doc: "notes/apps/vscode.md" },
      { title: "Claude Code", doc: "notes/apps/claude-code.md" },
      { title: "Codex", doc: "notes/apps/codex.md" },
      { title: "Antigravity CLI", doc: "notes/apps/antigravity-cli.md" },
      { title: "basic-memory", doc: "notes/apps/basic-memory.md" },
      { title: "Azure MCP", doc: "notes/apps/azure-mcp.md" },
      { title: "Flameshot", doc: "notes/apps/flameshot.md" },
      { title: "CurseForge", doc: "notes/apps/curseforge.md" },
      { title: "CurseForge fix-perms", doc: "notes/apps/curseforge-fix-perms.md" },
      { title: "Bottles", doc: "notes/apps/bottles.md" },
      { title: "MEGA", doc: "notes/apps/mega.md" },
      { title: "Spotify", doc: "notes/apps/spotify.md" },
      { title: "Zen", doc: "notes/apps/zen.md" },
      { title: "Apps and MIME", doc: "notes/apps/apps-and-mime.md" },
    ],
  },
  {
    section: "Services",
    items: [
      { title: "Service toggles", doc: "notes/services/service-toggles.md" },
      { title: "Jellyfin", doc: "notes/services/jellyfin.md" },
      { title: "Ollama", doc: "notes/services/ollama.md" },
      { title: "Duo", doc: "notes/services/duo.md" },
      { title: "grad-radar", doc: "notes/services/grad-radar.md" },
      { title: "credit-radar", doc: "notes/services/credit-radar.md" },
      { title: "Docker prune", doc: "notes/services/docker-prune.md" },
      { title: "libvirt", doc: "notes/services/libvirt.md" },
    ],
  },
  {
    section: "Repo",
    items: [
      { title: "Flake", doc: "notes/repo/flake.md" },
      { title: "Core", doc: "notes/repo/core.md" },
      { title: "Packages", doc: "notes/repo/packages.md" },
      { title: "Shell", doc: "notes/repo/shell.md" },
      { title: "Secrets", doc: "notes/repo/secrets.md" },
      { title: "Version bumps", doc: "notes/repo/version-bumps.md" },
      { title: "Link checker", doc: "notes/repo/link-checker.md" },
      { title: "Dead config", doc: "notes/repo/dead-config.md" },
      { title: "Router SSOT", doc: "notes/repo/router-ssot.md" },
      { title: "Prose style", doc: "notes/repo/prose-style.md" },
      { title: "VM boot", doc: "notes/repo/vm-boot.md" },
      { title: "Site", doc: "notes/repo/site.md" },
    ],
  },
  {
    section: "Guides",
    items: [
      { doc: "guides/README.md" },
      { title: "BIOS EX-B560M-V5", doc: "guides/bios-ex-b560m-v5.md" },
      { title: "Disaster recovery", doc: "guides/disaster-recovery.md" },
      { title: "Router hardening", doc: "guides/router-hardening.md" },
      { title: "FAI gateway router", doc: "guides/fai-gateway-router.md" },
      { title: "Per-client DNS block", doc: "guides/per-client-dns-block.md" },
      { title: "WireGuard and Moonlight", doc: "guides/wireguard-moonlight.md" },
      { title: "CESAR Windows manual steps", doc: "guides/cesar-windows-manual-steps.md" },
      { title: "Context exports", doc: "guides/context-exports.md" },
    ],
  },
  {
    section: "Log",
    items: [
      { title: "Open items", doc: "open-items.md" },
      { title: "Ideas", doc: "ideas.md" },
      {
        section: "History",
        items: [
          { doc: "history/README.md" },
          {
            section: "2026",
            items: [
              { title: "July", doc: "history/2026/07-july.md" },
              { title: "August", doc: "history/2026/08-august.md" },
              { title: "September", doc: "history/2026/09-september.md" },
            ],
          },
        ],
      },
      { title: "Arch Linux", doc: "arch-linux.md" },
      { title: "Arch parity audit", doc: "arch-parity-audit.md" },
    ],
  },
];
