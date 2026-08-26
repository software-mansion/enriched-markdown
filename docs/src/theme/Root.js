import React from 'react';
import { getInitColorSchemeScript } from '@mui/material/styles';
import { Experimental_CssVarsProvider as CssVarsProvider } from '@mui/material/styles';
import theme from '@site/src/theme/muiTheme';

// react-native-web's `useColorScheme` reads the OS `prefers-color-scheme` media
// query via a hardcoded `Appearance` singleton - it does not know about
// Docusaurus's manual light/dark toggle (which sets `data-theme` on <html>).
// The interactive examples render on react-native-web and switch their
// `markdownStyle` on `useColorScheme()`, so we repoint that singleton at the
// Docusaurus theme here. Client-only (guarded + lazily required so nothing runs
// during SSR), evaluated once at module load before any example mounts.
if (typeof document !== 'undefined') {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const { Appearance } = require('react-native');
  const getMode = () =>
    document.documentElement.getAttribute('data-theme') === 'dark'
      ? 'dark'
      : 'light';
  const listeners = new Set();
  Appearance.getColorScheme = () => getMode();
  Appearance.addChangeListener = (listener) => {
    listeners.add(listener);
    return { remove: () => listeners.delete(listener) };
  };
  new MutationObserver(() => {
    const colorScheme = getMode();
    listeners.forEach((listener) => listener({ colorScheme }));
  }).observe(document.documentElement, {
    attributes: true,
    attributeFilter: ['data-theme'],
  });
}

export default function Root({ children }) {
  return (
    <>
      {getInitColorSchemeScript()}
      <CssVarsProvider theme={theme}>{children}</CssVarsProvider>
    </>
  );
}
