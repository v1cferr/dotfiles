'use client';

// The provider is a client component only because the static search dialog is one: a function
// cannot cross the server boundary, so the layout hands it over from here.
import { RootProvider } from 'fumadocs-ui/provider/next';
import type { ReactNode } from 'react';
import StaticSearchDialog from '../components/search.tsx';

export function Provider({ children }: { children: ReactNode }) {
  return <RootProvider search={{ SearchDialog: StaticSearchDialog }}>{children}</RootProvider>;
}
