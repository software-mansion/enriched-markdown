// External platform store (framework-agnostic, module-level singleton).
//
// Using an external store rather than React context lets the choice be shared
// across INDEPENDENT React roots — the main app AND the small widget we mount
// into the navbar's `html` item both read/write the same value and stay in
// sync. Consumed via useSyncExternalStore in src/platform/context.tsx.

import {
  DEFAULT_PLATFORM,
  isPlatformId,
  PLATFORM_STORAGE_KEY,
  type PlatformId,
} from '@site/src/platform/config';

let current: PlatformId = DEFAULT_PLATFORM;
let initialized = false;
const listeners = new Set<() => void>();

function reflect() {
  if (typeof document !== 'undefined') {
    document.documentElement.dataset.platform = current;
  }
}

function emit() {
  reflect();
  listeners.forEach((listener) => listener());
}

function init() {
  if (initialized || typeof window === 'undefined') {
    return;
  }
  initialized = true;
  try {
    const stored = window.localStorage.getItem(PLATFORM_STORAGE_KEY);
    if (isPlatformId(stored)) {
      current = stored;
    }
  } catch {
    // ignore
  }
  reflect();
  // Cross-tab sync.
  window.addEventListener('storage', (event) => {
    if (event.key === PLATFORM_STORAGE_KEY && isPlatformId(event.newValue)) {
      current = event.newValue;
      emit();
    }
  });
}

export function subscribe(callback: () => void): () => void {
  init();
  listeners.add(callback);
  return () => listeners.delete(callback);
}

export function getSnapshot(): PlatformId {
  init();
  return current;
}

// Server (and first client render) always sees the default, so hydration is
// deterministic; the stored value is adopted right after via subscribe/emit.
export function getServerSnapshot(): PlatformId {
  return DEFAULT_PLATFORM;
}

export function setPlatform(next: PlatformId): void {
  if (!isPlatformId(next) || next === current) {
    return;
  }
  current = next;
  try {
    window.localStorage.setItem(PLATFORM_STORAGE_KEY, next);
  } catch {
    // ignore
  }
  emit();
}
