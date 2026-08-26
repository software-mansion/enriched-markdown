import React from 'react';
import clsx from 'clsx';
import copy from 'copy-text-to-clipboard';
import IconCopy from '@theme/Icon/Copy';
import IconSuccess from '@theme/Icon/Success';
import styles from './styles.module.css';

// Copy-to-clipboard icon button with transient "copied" feedback. Takes a
// getter rather than a string so the caller resolves the text at click time -
// LivePreview hands back the reader's current (edited) code, not the original.

interface Props {
  getText: () => string;
  className?: string;
}

export default function CopyButton({ getText, className }: Props) {
  const [copied, setCopied] = React.useState(false);
  const timeoutRef = React.useRef<ReturnType<typeof setTimeout>>();

  React.useEffect(() => () => clearTimeout(timeoutRef.current), []);

  const onClick = () => {
    copy(getText());
    setCopied(true);
    clearTimeout(timeoutRef.current);
    timeoutRef.current = setTimeout(() => setCopied(false), 1200);
  };

  return (
    <button
      type="button"
      aria-label={copied ? 'Copied' : 'Copy code'}
      title={copied ? 'Copied' : 'Copy code'}
      className={clsx(
        styles.iconButton,
        copied && styles.iconButtonActive,
        className
      )}
      onClick={onClick}
    >
      {copied ? (
        <IconSuccess className={styles.icon} />
      ) : (
        <IconCopy className={styles.icon} />
      )}
    </button>
  );
}
