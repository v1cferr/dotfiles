// The options every layout shares: the title in the navbar and the link back to the repo.
import type { BaseLayoutProps } from 'fumadocs-ui/layouts/shared';
import { REPO_URL, SITE_NAME } from './repo.ts';

export function baseOptions(): BaseLayoutProps {
  return {
    nav: { title: SITE_NAME },
    githubUrl: REPO_URL,
  };
}
