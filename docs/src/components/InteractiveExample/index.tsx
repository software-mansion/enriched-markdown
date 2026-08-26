import React from 'react';
import BrowserOnly from '@docusaurus/BrowserOnly';
import CodeBlock from '@theme/CodeBlock';
import ExampleControls, {
  type ExampleTab,
} from '@site/src/components/ExampleControls';
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
  const [tab, setTab] = React.useState<ExampleTab>('preview');
  const [resetKey, setResetKey] = React.useState(0);

  const isLive = !comingSoon && Component != null;

  return (
    <div className={styles.container}>
      <ExampleControls
        tab={tab}
        onTabChange={setTab}
        getCopyText={() => src.trim()}
        onReset={isLive ? () => setResetKey((key) => key + 1) : undefined}
      />

      {tab === 'preview' ? (
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
