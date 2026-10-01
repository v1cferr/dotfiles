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

/** The Lucide icon a top-level group carries, by name: this file runs on bare node, without React. */
export type SectionIcon =
  | 'scale'
  | 'hard-drive'
  | 'cpu'
  | 'network'
  | 'monitor'
  | 'app-window'
  | 'server'
  | 'git-branch'
  | 'book-open'
  | 'scroll-text';

/** A group in the sidebar. A `doc` with no title as its first item becomes the group's own page. */
export interface NavSection {
  section: string;
  icon?: SectionIcon;
  items: NavItem[];
}

export type NavItem = NavPage | NavSection;

export const navigation: NavItem[] = [
  { title: "Home", doc: "README.md" },
  { title: "Rules", doc: "rules.md" },
  {
    section: "Decisions",
    icon: "scale",
    items: [
      { doc: "decisions/README.md" },
      { title: "0001 Own Nix palette", doc: "decisions/0001-own-nix-palette.md" },
      { title: "0002 UI font in system", doc: "decisions/0002-ui-font-in-system.md" },
      { title: "0003 Agent contract", doc: "decisions/0003-agent-contract-in-managed-layer.md" },
      { title: "0004 MkDocs (superseded)", doc: "decisions/0004-mkdocs-for-the-site.md" },
      { title: "0005 Fumadocs", doc: "decisions/0005-fumadocs-for-the-site.md" },
      { title: "0006 No disk encryption", doc: "decisions/0006-no-disk-encryption.md" },
      { title: "0007 GRUB over lanzaboote", doc: "decisions/0007-grub-over-lanzaboote.md" },
      { title: "0008 No offsite backup yet", doc: "decisions/0008-no-offsite-backup-yet.md" },
      { title: "0009 Modules, hosts, tools", doc: "decisions/0009-modules-hosts-tools-layout.md" },
      { title: "0010 No component library", doc: "decisions/0010-visual-layer-without-component-library.md" },
    ],
  },
  { title: "How the notes work", doc: "notes/README.md" },
  {
    section: "Boot and storage",
    icon: "hard-drive",
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
    icon: "cpu",
    items: [
      { title: "GPU", doc: "notes/hardware/gpu.md" },
      { title: "GPU RGB", doc: "notes/hardware/gpu-rgb.md" },
      { title: "Monitors", doc: "notes/hardware/monitors.md" },
      { title: "Fonts", doc: "notes/hardware/fonts.md" },
      { title: "Mouse", doc: "notes/hardware/mouse.md" },
      { title: "Razer", doc: "notes/hardware/razer.md" },
      { title: "Android", doc: "notes/hardware/android.md" },
      { title: "OOM", doc: "notes/hardware/oom.md" },
      { title: "Webcam", doc: "notes/hardware/webcam.md" },
    ],
  },
  {
    section: "Network",
    icon: "network",
    items: [
      { title: "Network", doc: "notes/network/network.md" },
      { title: "Exposure", doc: "notes/network/exposure.md" },
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
    icon: "monitor",
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
    icon: "app-window",
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
    icon: "server",
    items: [
      { title: "Service toggles", doc: "notes/services/service-toggles.md" },
      { title: "Jellyfin", doc: "notes/services/jellyfin.md" },
      { title: "Immich", doc: "notes/services/immich.md" },
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
    icon: "git-branch",
    items: [
      { title: "Flake", doc: "notes/repo/flake.md" },
      { title: "Core", doc: "notes/repo/core.md" },
      { title: "Packages", doc: "notes/repo/packages.md" },
      { title: "Shell", doc: "notes/repo/shell.md" },
      { title: "Secrets", doc: "notes/repo/secrets.md" },
      { title: "Version bumps", doc: "notes/repo/version-bumps.md" },
      { title: "Link checker", doc: "notes/repo/link-checker.md" },
      { title: "Dead config", doc: "notes/repo/dead-config.md" },
      { title: "Rules index", doc: "notes/repo/rules-index.md" },
      { title: "Ownership", doc: "notes/repo/ownership.md" },
      { title: "Hardening", doc: "notes/repo/hardening.md" },
      { title: "Router SSOT", doc: "notes/repo/router-ssot.md" },
      { title: "Prose style", doc: "notes/repo/prose-style.md" },
      { title: "VM boot", doc: "notes/repo/vm-boot.md" },
      { title: "Site", doc: "notes/repo/site.md" },
      { title: "GitHub settings", doc: "notes/repo/github-settings.md" },
      { title: "Eval metrics", doc: "notes/repo/eval-metrics.md" },
      { title: "Usage audit", doc: "notes/repo/usage-audit.md" },
      { title: "README", doc: "notes/repo/readme.md" },
      { title: "License", doc: "notes/repo/license.md" },
    ],
  },
  {
    section: "Guides",
    icon: "book-open",
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
    icon: "scroll-text",
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
