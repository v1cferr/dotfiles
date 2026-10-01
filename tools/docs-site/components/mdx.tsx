// The components a page can reach for. Only Mermaid is added: the markdown here is prose, and a
// component nothing uses is dead config (rule 16).
import type { MDXComponents } from 'mdx/types';
import defaultMdxComponents from 'fumadocs-ui/mdx';
import { Mermaid } from './mermaid.tsx';

export function getMDXComponents(components?: MDXComponents) {
  return {
    ...defaultMdxComponents,
    Mermaid,
    ...components,
  } satisfies MDXComponents;
}
