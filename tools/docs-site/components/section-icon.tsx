// The icon of each nav group, named in lib/navigation.ts and drawn here, so the nav stays plain
// data the gate can read on bare node. The Record makes a name with no icon a type error.
import {
  AppWindow,
  BookOpen,
  Cpu,
  GitBranch,
  HardDrive,
  type LucideIcon,
  Monitor,
  Network,
  ScrollText,
  Scale,
  Server,
} from 'lucide-react';
import type { SectionIcon } from '../lib/navigation.ts';

const ICONS: Record<SectionIcon, LucideIcon> = {
  scale: Scale,
  'hard-drive': HardDrive,
  cpu: Cpu,
  network: Network,
  monitor: Monitor,
  'app-window': AppWindow,
  server: Server,
  'git-branch': GitBranch,
  'book-open': BookOpen,
  'scroll-text': ScrollText,
};

export function sectionIcon(name: SectionIcon) {
  const Icon = ICONS[name];
  // Decorative: the group's name is always printed next to it.
  return <Icon aria-hidden="true" />;
}
