// sitemap.xml, which MkDocs emitted and a static export does not until asked. No `lastModified`:
// the sandbox has no git and a build timestamp would only make the file lie.
import type { MetadataRoute } from 'next';
import { SITE_ORIGIN } from '../lib/domain.ts';
import { source } from '../lib/source.ts';
import { servedUrl } from '../lib/urls.ts';

export const dynamic = 'force-static';

export default function sitemap(): MetadataRoute.Sitemap {
  return source
    .getPages()
    // ABSOLUTE: a sitemap with a relative loc is a sitemap a crawler rejects.
    .map((page) => ({ url: SITE_ORIGIN + servedUrl(page.url) }))
    .toSorted((a, b) => (a.url < b.url ? -1 : 1));
}
