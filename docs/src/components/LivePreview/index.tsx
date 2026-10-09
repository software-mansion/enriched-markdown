import React from 'react';
import clsx from 'clsx';
import BrowserOnly from '@docusaurus/BrowserOnly';
import CodeBlock from '@theme/CodeBlock';
import { useColorMode } from '@docusaurus/theme-common';
import ExampleControls, {
  EditableBadge,
  type ExampleTab,
} from '@site/src/components/ExampleControls';
import lightCodeTheme from '@site/src/theme/CodeBlock/highlighting-light.js';
import darkCodeTheme from '@site/src/theme/CodeBlock/highlighting-dark.js';
import { defaultMarkdownStyle } from '@site/src/examples/_shared/markdownTheme';
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
  /**
   * When true, the prop being demonstrated has no effect on the web build, so
   * the example can't run live. The Preview tab shows a "not available on web"
   * banner and the Code tab shows the (non-editable) source for reference.
   */
  unavailable?: boolean;
  /**
   * Overrides the default banner copy shown in `unavailable` mode - name the
   * platform(s) the prop applies to, e.g. "iOS only" or "iOS and Android only".
   */
  unavailableReason?: React.ReactNode;
  /**
   * Overrides the banner's short badge label (default "Not available on web").
   * Use for docs-only limitations, e.g. "Needs KaTeX" for math examples.
   */
  unavailableLabel?: string;
}

function Unavailable({
  reason,
  label = 'Not available on web',
}: {
  reason?: React.ReactNode;
  label?: string;
}) {
  return (
    <div className={styles.unavailable}>
      <span className={styles.unavailableBadge}>{label}</span>
      <p className={styles.unavailableText}>
        {reason ?? (
          <>
            This prop has no effect on the web build, so it can't be previewed
            here - the code is shown for reference.
          </>
        )}
      </p>
    </div>
  );
}

// Static (non-live) variant for props that don't run on web: no react-live,
// just the tab chrome with a "not available" banner in Preview and a read-only
// CodeBlock in Code. Defaults to the Code tab since the preview is only a
// banner.
function UnavailableExample({
  src,
  reason,
  label,
}: {
  src: string;
  reason?: React.ReactNode;
  label?: string;
}) {
  const [tab, setTab] = React.useState<ExampleTab>('code');
  return (
    <div className={styles.container}>
      <ExampleControls
        tab={tab}
        onTabChange={setTab}
        getCopyText={() => src.trim()}
      />
      {tab === 'preview' ? (
        <div className={styles.preview}>
          <Unavailable reason={reason} label={label} />
        </div>
      ) : (
        <div className={styles.code}>
          <CodeBlock language="tsx">{src.trim()}</CodeBlock>
        </div>
      )}
    </div>
  );
}

// The floating control cluster lives inside <LiveProvider>, so it can read the
// reader's current (edited) code from react-live's context for the copy button.
// `liveContext` is passed in because react-live is required lazily (SSR-safe).
// react-live keeps the `code` prop static and exposes the latest transpiled
// source as `newCode`, so copy prefers `newCode` to grab the reader's edits.
function LiveControls({
  liveContext,
  tab,
  onTabChange,
  onReset,
}: {
  liveContext: React.Context<{ code: string; newCode?: string }>;
  tab: ExampleTab;
  onTabChange: (tab: ExampleTab) => void;
  onReset: () => void;
}) {
  const { code, newCode } = React.useContext(liveContext);
  return (
    <ExampleControls
      tab={tab}
      onTabChange={onTabChange}
      getCopyText={() => newCode ?? code}
      onReset={onReset}
      badge={tab === 'code' ? <EditableBadge /> : undefined}
    />
  );
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

// The react-live tree lives in its own component (rendered inside BrowserOnly)
// so `scope` can be memoized. react-live re-runs its transpile effect whenever
// the `scope` identity changes; an unmemoized scope rebuilt every render would
// re-transpile the original `src` on each keystroke and revert the reader's
// edits, so the memo is what makes live editing actually update the preview.
function Playground({
  src,
  scope,
  codeTheme,
  tab,
  onTabChange,
  resetKey,
  onReset,
}: {
  src: string;
  scope?: Record<string, unknown>;
  codeTheme: unknown;
  tab: ExampleTab;
  onTabChange: (tab: ExampleTab) => void;
  resetKey: number;
  onReset: () => void;
}) {
  // Required lazily so nothing here is evaluated during server-side rendering.
  const {
    LiveProvider,
    LiveEditor,
    LivePreview: LivePreviewPane,
    LiveError,
    LiveContext,
    // eslint-disable-next-line @typescript-eslint/no-var-requires
  } = require('react-live');
  const RN = require('react-native');
  const {
    EnrichedMarkdownText,
    // eslint-disable-next-line @typescript-eslint/no-var-requires
  } = require('react-native-enriched-markdown');

  const fullScope = React.useMemo(
    () => ({
      React,
      useState: React.useState,
      useRef: React.useRef,
      useEffect: React.useEffect,
      useMemo: React.useMemo,
      useCallback: React.useCallback,
      useColorScheme: RN.useColorScheme,
      View: RN.View,
      Text: RN.Text,
      Button: RN.Button,
      Pressable: RN.Pressable,
      StyleSheet: RN.StyleSheet,
      Linking: RN.Linking,
      EnrichedMarkdownText,
      // Shared default palette used by the API-reference examples so each one
      // can start from a full theme in a single line and override via spread.
      defaultMarkdownStyle,
      ...scope,
    }),
    // Module requires are stable; only the caller-supplied `scope` can change.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [scope]
  );

  return (
    <LiveProvider
      key={resetKey}
      code={src.trim()}
      transformCode={toRenderable}
      scope={fullScope}
      theme={codeTheme}
      noInline
    >
      <div className={styles.container}>
        <LiveControls
          liveContext={LiveContext}
          tab={tab}
          onTabChange={onTabChange}
          onReset={onReset}
        />

        {/* Both panes stay mounted and the inactive one is hidden, so the
            editor keeps the reader's edits: react-live re-seeds a remounted
            LiveEditor from the static `code` prop, losing typed changes. */}
        <div
          className={clsx(styles.preview, tab !== 'preview' && styles.hidden)}
        >
          <LivePreviewPane />
        </div>
        <div className={clsx(styles.editor, tab !== 'code' && styles.hidden)}>
          <LiveEditor />
        </div>

        <LiveError className={styles.error} />
      </div>
    </LiveProvider>
  );
}

export default function LivePreview({
  src,
  scope,
  unavailable = false,
  unavailableReason,
  unavailableLabel,
}: Props) {
  const [tab, setTab] = React.useState<ExampleTab>('preview');
  const [resetKey, setResetKey] = React.useState(0);
  const { colorMode } = useColorMode();
  const codeTheme = colorMode === 'dark' ? darkCodeTheme : lightCodeTheme;

  if (unavailable) {
    return (
      <UnavailableExample
        src={src}
        reason={unavailableReason}
        label={unavailableLabel}
      />
    );
  }

  return (
    <BrowserOnly fallback={<div className={styles.container}>Loading…</div>}>
      {() => (
        <Playground
          src={src}
          scope={scope}
          codeTheme={codeTheme}
          tab={tab}
          onTabChange={setTab}
          resetKey={resetKey}
          onReset={() => setResetKey((key) => key + 1)}
        />
      )}
    </BrowserOnly>
  );
}
