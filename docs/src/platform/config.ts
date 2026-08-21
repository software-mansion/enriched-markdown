// Single source of truth for the platform selector prototype.
//
// The docs are written ONCE. Platform is a cross-cutting selector (like a
// language switcher): only code examples and availability badges change when
// the reader switches platform. Per-platform *version numbers* live here as
// display labels — they are NOT Docusaurus versions (those are build-time /
// URL snapshots and cannot be a client-side toggle).

export type PlatformId = 'rn' | 'ios' | 'android';

export interface PlatformDef {
  id: PlatformId;
  /** Shown in the selector and in badges. */
  label: string;
  /** Current released package version — display only. */
  version: string;
}

// Order here is the order shown in the selector. Add `web` when it ships —
// no other change is needed to light it up.
export const PLATFORMS: PlatformDef[] = [
  { id: 'rn', label: 'React Native', version: '1.0.2' },
  { id: 'ios', label: 'iOS', version: '0.1.0' },
  { id: 'android', label: 'Android', version: '0.1.0' },
];

export const DEFAULT_PLATFORM: PlatformId = 'rn';

// Mirrors Docusaurus' own `docusaurus.tab.<groupId>` storage convention, so a
// future built-in `<Tabs groupId="platform">` shares the same choice as our
// global selector.
export const PLATFORM_STORAGE_KEY = 'docusaurus.tab.platform';

const VALID_IDS = new Set<string>(PLATFORMS.map(p => p.id));

export function isPlatformId(value: unknown): value is PlatformId {
  return typeof value === 'string' && VALID_IDS.has(value);
}

export function getPlatform(id: PlatformId): PlatformDef {
  return PLATFORMS.find(p => p.id === id) ?? PLATFORMS[0];
}
