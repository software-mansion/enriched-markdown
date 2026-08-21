import React from 'react';
import clsx from 'clsx';
import { usePlatform } from '@site/src/platform/context';
import { PLATFORMS, type PlatformId } from '@site/src/platform/config';
import styles from './styles.module.css';

// Presence per platform: truthy = present, false/undefined = not present.
// (Strings are still accepted and treated as present, for convenience.)
type Present = boolean | string | undefined;

interface SupportProps {
  rn?: Present;
  ios?: Present;
  android?: Present;
}

function isPresent(value: Present): boolean {
  return value !== undefined && value !== false;
}

// Context-aware inline badge: shows whether the feature is present on the
// CURRENTLY selected platform. Updates live as the reader switches platform.
export function PlatformBadge(props: SupportProps) {
  const { platform } = usePlatform();
  const present = isPresent(props[platform]);

  return (
    <span className={clsx(styles.badge, present ? styles.yes : styles.no)}>
      {present ? 'Present' : 'Not present'}
    </span>
  );
}

// Static, platform-independent row showing presence across all platforms at
// once. Good for API-reference tables where you want the full picture.
export function Availability(props: SupportProps) {
  return (
    <span className={styles.availability}>
      {PLATFORMS.map((p) => {
        const present = isPresent(props[p.id as PlatformId]);
        return (
          <span
            key={p.id}
            className={clsx(
              styles.chip,
              present ? styles.chipYes : styles.chipNo,
            )}>
            {p.label}: {present ? 'present' : 'not present'}
          </span>
        );
      })}
    </span>
  );
}
