// The content source: docs/ read in place, with the URL model of lib/urls.ts on top of it.
// Why the files did not move and the URLs did not change: docs/notes/repo/site.md
import { loader } from 'fumadocs-core/source';
import { pageSchema } from 'fumadocs-core/source/schema';
import { defineDocs } from 'fumadocs-mdx/macro';
import { z } from 'zod';
import { titleFromMarkdown } from './title.ts';
import { docSlugs, docUrl } from './urls.ts';

const docs = defineDocs({
  dir: '../docs',
  docs: {
    // The schema runs BEFORE the markdown is compiled and is handed the raw source, which is the
    // only hook where a title can be derived without writing frontmatter into docs/.
    schema: (ctx) => {
      const title = titleFromMarkdown(ctx.source);
      if (title === undefined) throw new Error(`${ctx.path} has no H1, so the page has no title`);
      return pageSchema.extend({ title: z.string().default(title) });
    },
  },
});

export const source = loader({
  source: docs.toFumadocsSource(),
  // The docs are the WHOLE site, so the root is `/` and not `/docs`. `url` is what actually
  // builds every href; `baseUrl` is only the fallback the type demands.
  baseUrl: '/',
  url: docUrl,
  slugs: (file) => docSlugs(file.path),
});
