import React from 'react';
import styles from './styles.module.css';

function AndroidIcon() {
  return (
    <svg
      className={styles.icon}
      viewBox="0 0 24 24"
      role="presentation"
      aria-hidden="true">
      <path d="M17.6 9.48l1.84-3.18a.4.4 0 00-.14-.55.4.4 0 00-.55.14l-1.86 3.22a11.4 11.4 0 00-9.78 0L5.25 5.89a.4.4 0 00-.55-.14.4.4 0 00-.14.55L6.4 9.48A10.8 10.8 0 001 18h22a10.8 10.8 0 00-5.4-8.52zM7 15.25a1 1 0 110-2 1 1 0 010 2zm10 0a1 1 0 110-2 1 1 0 010 2z" />
    </svg>
  );
}

function AppleIcon() {
  return (
    <svg
      className={styles.icon}
      viewBox="0 0 24 24"
      role="presentation"
      aria-hidden="true">
      <path d="M16.36 12.68c-.02-2.05 1.68-3.03 1.75-3.08-.95-1.4-2.44-1.59-2.97-1.61-1.26-.13-2.47.74-3.11.74-.64 0-1.63-.72-2.68-.7-1.38.02-2.65.8-3.36 2.03-1.43 2.49-.37 6.17 1.03 8.19.68.99 1.5 2.1 2.57 2.06 1.03-.04 1.42-.66 2.67-.66 1.24 0 1.6.66 2.68.64 1.11-.02 1.81-1 2.49-2 .78-1.15 1.11-2.26 1.13-2.32-.02-.01-2.17-.83-2.19-3.29zM14.4 6.65c.57-.69.95-1.65.85-2.6-.82.03-1.81.54-2.39 1.23-.52.61-.98 1.58-.86 2.51.91.07 1.84-.46 2.4-1.14z" />
    </svg>
  );
}

function GlobeIcon() {
  return (
    <svg
      className={styles.icon}
      viewBox="0 0 24 24"
      role="presentation"
      aria-hidden="true">
      <path d="M12 2a10 10 0 100 20 10 10 0 000-20zm6.92 6h-2.95a15.7 15.7 0 00-1.38-3.56A8.03 8.03 0 0118.92 8zM12 4.04c.83 1.2 1.48 2.53 1.91 3.96h-3.82c.43-1.43 1.08-2.76 1.91-3.96zM4.26 14a7.82 7.82 0 010-4h3.38a16.5 16.5 0 000 4H4.26zm.82 2h2.95c.3 1.26.76 2.46 1.38 3.56A7.99 7.99 0 015.08 16zm2.95-8H5.08a7.99 7.99 0 014.33-3.56A15.7 15.7 0 008.03 8zM12 19.96c-.83-1.2-1.48-2.53-1.91-3.96h3.82A13.6 13.6 0 0112 19.96zM14.34 14H9.66a14.7 14.7 0 010-4h4.68a14.7 14.7 0 010 4zm.25 5.56c.62-1.1 1.08-2.3 1.38-3.56h2.95a8.03 8.03 0 01-4.33 3.56zM16.36 14a16.5 16.5 0 000-4h3.38a7.82 7.82 0 010 4h-3.38z" />
    </svg>
  );
}

interface PlatformBadgeProps {
  children?: React.ReactNode;
}

export function AndroidBadge({ children }: PlatformBadgeProps) {
  return (
    <span className={`${styles.badge} ${styles.android}`}>
      <AndroidIcon />
      {children ?? 'Android only'}
    </span>
  );
}

export function IosBadge({ children }: PlatformBadgeProps) {
  return (
    <span className={`${styles.badge} ${styles.ios}`}>
      <AppleIcon />
      {children ?? 'iOS only'}
    </span>
  );
}

export function WebBadge({ children }: PlatformBadgeProps) {
  return (
    <span className={`${styles.badge} ${styles.web}`}>
      <GlobeIcon />
      {children ?? 'Web only'}
    </span>
  );
}
