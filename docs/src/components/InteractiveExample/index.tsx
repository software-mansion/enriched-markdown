import React from 'react';
import clsx from 'clsx';
import BrowserOnly from '@docusaurus/BrowserOnly';
import CodeBlock from '@theme/CodeBlock';
import styles from './styles.module.css';

// One example .tsx file is the single source of truth: the doc page imports it
// as a runnable component (the Preview) and, via `!!raw-loader!`, as its own
// source text (the Code). The example renders the library's web build - see
// the alias in docusaurus.config.js. It runs client-side only (BrowserOnly)
// because that build injects a <style> into document.head at module eval,
// which would crash server-side rendering during `yarn build`.

interface Props {
  /** Raw source of the example, imported via `!!raw-loader!`. Shown in Code. */
  src: string;
  /** The example component to run live in the Preview tab. */
  component?: React.FC;
  /**
   * When true, the Preview shows a "coming soon" banner instead of running
   * `component`. Used for elements not yet available on web (e.g. the input).
   */
  comingSoon?: boolean;
}

enum Tab {
  PREVIEW,
  CODE,
}

function ComingSoon() {
  return (
    <div className={styles.comingSoon}>
      <span className={styles.comingSoonBadge}>Coming soon</span>
      <p className={styles.comingSoonText}>
        A live preview for this example is not available yet. Web support for
        the editable input is in progress - the code is shown for reference.
      </p>
    </div>
  );
}

export default function InteractiveExample({
  src,
  component: Component,
  comingSoon = false,
}: Props) {
  const [tab, setTab] = React.useState<Tab>(Tab.PREVIEW);
  const [resetKey, setResetKey] = React.useState(0);

  const isLive = !comingSoon && Component != null;

  return (
    <div className={styles.container}>
      <div className={styles.toolbar}>
        <div className={styles.tabs}>
          <button
            type="button"
            className={clsx(styles.tab, tab === Tab.PREVIEW && styles.tabActive)}
            onClick={() => setTab(Tab.PREVIEW)}
          >
            Preview
          </button>
          <button
            type="button"
            className={clsx(styles.tab, tab === Tab.CODE && styles.tabActive)}
            onClick={() => setTab(Tab.CODE)}
          >
            Code
          </button>
        </div>
        {isLive && tab === Tab.PREVIEW && (
          <button
            type="button"
            className={styles.reset}
            onClick={() => setResetKey((key) => key + 1)}
          >
            Reset
          </button>
        )}
      </div>

      {tab === Tab.PREVIEW ? (
        <div className={styles.preview}>
          {isLive ? (
            <BrowserOnly
              fallback={<div className={styles.loading}>Loading...</div>}
            >
              {() => <Component key={resetKey} />}
            </BrowserOnly>
          ) : (
            <ComingSoon />
          )}
        </div>
      ) : (
        <div className={styles.code}>
          <CodeBlock language="tsx">{src.trim()}</CodeBlock>
        </div>
      )}
    </div>
  );
}
