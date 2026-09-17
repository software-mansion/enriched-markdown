import React from 'react';
import clsx from 'clsx';
import CopyButton from './CopyButton';
import ResetIcon from './ResetIcon';
import styles from './styles.module.css';

// Shared floating chrome for the example boxes (InteractiveExample and
// LivePreview), modelled on the Reanimated docs box: no top toolbar bar -
// instead a Preview/Code tab cluster plus a copy button float in the top-right
// corner, and a reset button floats over the bottom-right of the preview.
//
// Presentational only: the host owns tab state, the copy source, and reset.
// It must be rendered as a child of a `position: relative` container so the
// absolutely-positioned clusters anchor to the box.

export type ExampleTab = 'preview' | 'code';

export function EditableBadge() {
  return (
    <span className={styles.badge}>
      <span className={styles.badgeDot} />
      Editable
    </span>
  );
}

interface Props {
  tab: ExampleTab;
  onTabChange: (tab: ExampleTab) => void;
  getCopyText: () => string;
  /** Omit to hide the reset button (e.g. a `comingSoon` preview). */
  onReset?: () => void;
  /** Extra affordance shown left of the tabs, e.g. LivePreview's "Editable". */
  badge?: React.ReactNode;
}

export default function ExampleControls({
  tab,
  onTabChange,
  getCopyText,
  onReset,
  badge,
}: Props) {
  return (
    <>
      <div className={styles.topControls}>
        {badge}
        <div className={styles.tabs}>
          <button
            type="button"
            className={clsx(styles.tab, tab === 'preview' && styles.tabActive)}
            onClick={() => onTabChange('preview')}
          >
            Preview
          </button>
          <button
            type="button"
            className={clsx(styles.tab, tab === 'code' && styles.tabActive)}
            onClick={() => onTabChange('code')}
          >
            Code
          </button>
        </div>
        <CopyButton getText={getCopyText} />
      </div>

      {onReset && tab === 'preview' && (
        <button
          type="button"
          aria-label="Reset example"
          title="Reset example"
          className={styles.resetButton}
          onClick={onReset}
        >
          <ResetIcon className={styles.icon} />
        </button>
      )}
    </>
  );
}
