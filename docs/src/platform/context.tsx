import { useSyncExternalStore } from 'react';
import {
  getServerSnapshot,
  getSnapshot,
  setPlatform,
  subscribe,
} from '@site/src/platform/store';
import type { PlatformId } from '@site/src/platform/config';

interface PlatformHook {
  platform: PlatformId;
  setPlatform: (platform: PlatformId) => void;
}

// Reads the shared, page-wide external store. The navbar selector and every
// content component stay in sync through it, and the choice persists across
// pages.
export function usePlatform(): PlatformHook {
  const platform = useSyncExternalStore(
    subscribe,
    getSnapshot,
    getServerSnapshot,
  );
  return { platform, setPlatform };
}
