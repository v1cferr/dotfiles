// The components a page can reach for. Mermaid is added, and `a` and `code` take over ONLY what
// remark-repo-links marked as source: the markdown here is prose, and a component nothing uses is
// dead config (rule 16). The source half: docs/notes/repo/site-sources.md
import type { MDXComponents } from 'mdx/types';
import defaultMdxComponents from 'fumadocs-ui/mdx';
import { Mermaid } from './mermaid.tsx';
import { SourceCode, SourceLink } from './source/source-link.tsx';

const DefaultLink = defaultMdxComponents.a;

export function getMDXComponents(components?: MDXComponents) {
  return {
    ...defaultMdxComponents,
    Mermaid,
    a: (props) => ('data-source-path' in props ? <SourceLink {...props} /> : <DefaultLink {...props} />),
    code: (props) => ('data-source-ref' in props ? <SourceCode {...props} /> : <code {...props} />),
    ...components,
  } satisfies MDXComponents;
}
