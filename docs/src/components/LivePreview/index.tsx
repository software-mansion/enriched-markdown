import React from 'react';
import BrowserOnly from '@docusaurus/BrowserOnly';
import styles from './styles.module.css';

// A live, editable playground: the code is shown in an editor and the Preview
// re-renders as you type. Distinct from `InteractiveExample`, which is a static
// Preview/Code widget. The example .tsx file is still the single source of
// truth - it's passed in as `src` and runs live here.
//
// The library's web build injects a <style> at module eval and react-live's
// editor touches browser APIs, so the whole thing renders inside BrowserOnly.

interface Props {
  /** Raw source of the example, imported via `!!raw-loader!`. */
  src: string;
  /**
   * Extra scope entries merged into the default scope (React hooks, common
   * react-native-web primitives, and `EnrichedMarkdownText`). Only genuine
   * imports belong here - anything an example treats as editable content
   * (markdown text, `markdownStyle`, …) should live inline in the example so
   * the reader can play with it in the editor.
   */
  scope?: Record<string, unknown>;
}

// Turn an example module ("import ...; export default function App() {...}")
// into something react-live can run in `noInline` mode: strip imports (their
// bindings come from `scope`) and render <App />.
function toRenderable(code: string): string {
  return (
    code
      // `import ... from '...'` (single- or multi-line)
      .replace(/^\s*import\s+[\s\S]*?from\s+['"][^'"]+['"];?/gm, '')
      // bare `import '...'`
      .replace(/^\s*import\s+['"][^'"]+['"];?/gm, '')
      .replace(/export\s+default\s+function\s+App/, 'function App')
      .replace(/export\s+default\s+App\s*;?/, '') +
    '\nrender(<App />);'
  );
}

export default function LivePreview({ src, scope }: Props) {
  const [resetKey, setResetKey] = React.useState(0);

  return (
    <BrowserOnly
      fallback={<div className={styles.container}>Loading…</div>}
    >
      {() => {
        // Required lazily inside BrowserOnly so nothing here is evaluated
        // during server-side rendering.
        const {
          LiveProvider,
          LiveEditor,
          LivePreview: LivePreviewPane,
          LiveError,
          // eslint-disable-next-line @typescript-eslint/no-var-requires
        } = require('react-live');
        const { themes } = require('prism-react-renderer');
        const RN = require('react-native');
        const {
          EnrichedMarkdownText,
          // eslint-disable-next-line @typescript-eslint/no-var-requires
        } = require('react-native-enriched-markdown');

        const fullScope = {
          React,
          useState: React.useState,
          useRef: React.useRef,
          useEffect: React.useEffect,
          useMemo: React.useMemo,
          useCallback: React.useCallback,
          View: RN.View,
          Text: RN.Text,
          Button: RN.Button,
          Pressable: RN.Pressable,
          StyleSheet: RN.StyleSheet,
          Linking: RN.Linking,
          EnrichedMarkdownText,
          ...scope,
        };

        return (
          <LiveProvider
            key={resetKey}
            code={src.trim()}
            transformCode={toRenderable}
            scope={fullScope}
            theme={themes.vsDark}
            noInline
          >
            <div className={styles.container}>
              <div className={styles.toolbar}>
                <span className={styles.label}>
                  <span className={styles.liveDot} />
                  Live example — edit the code
                </span>
                <button
                  type="button"
                  className={styles.reset}
                  onClick={() => setResetKey((key) => key + 1)}
                >
                  Reset
                </button>
              </div>

              <div className={styles.preview}>
                <LivePreviewPane />
              </div>

              <div className={styles.editorLabel}>Code (editable)</div>
              <div className={styles.editor}>
                <LiveEditor />
              </div>

              <LiveError className={styles.error} />
            </div>
          </LiveProvider>
        );
      }}
    </BrowserOnly>
  );
}
