import React from 'react';
import { usePlatform } from '@site/src/platform/context';
import type { PlatformId } from '@site/src/platform/config';

interface PlatformProps {
  // Show children only for these platform(s). Accepts a single id or a
  // comma-separated / array list, e.g. only="ios" or only="ios,android".
  only: PlatformId | PlatformId[] | string;
  children: React.ReactNode;
}

function normalize(only: PlatformProps['only']): string[] {
  if (Array.isArray(only)) {
    return only;
  }
  return String(only)
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
}

// Conditional block: renders its children only when the selected platform
// matches. Prose is written once; wrap only the parts that differ.
export default function Platform({ only, children }: PlatformProps) {
  const { platform } = usePlatform();
  if (!normalize(only).includes(platform)) {
    return null;
  }
  return <>{children}</>;
}
