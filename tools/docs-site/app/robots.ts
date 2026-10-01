// robots.txt: everything is public, and the point of the file is to name the sitemap.
import type { MetadataRoute } from 'next';
import { SITE_ORIGIN } from '../lib/domain.ts';

export const dynamic = 'force-static';

export default function robots(): MetadataRoute.Robots {
  return {
    rules: { userAgent: '*', allow: '/' },
    sitemap: `${SITE_ORIGIN}/sitemap.xml`,
  };
}
