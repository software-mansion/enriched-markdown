import type { NormalizedMarkdownShortcuts } from '../../../normalizeMarkdownShortcuts';
import { blockTypeForHeadingLevel, type BlockType } from '../model/blocks';

export interface MarkdownShortcutMatch {
  type: BlockType;
  level: number;
}

// Anything longer is a number the user is writing, not a list marker.
const MAX_ORDERED_MARKER_DIGITS = 9;

export function markdownShortcutsEnabled(
  config: NormalizedMarkdownShortcuts
): boolean {
  return config.heading || config.unorderedList || config.orderedList;
}

/**
 * Matches `prefix` - the paragraph text before the space the user just typed,
 * from the line start - against the families `config` enables: `#`-`######`,
 * `-`/`*`/`+`, `1.`/`1)`. Pure text matching, ported from the natives'
 * `MarkdownShortcutMatcher`; the caller owns the edit. Ordered items match any
 * number, as the store renumbers them, so `3.` on a fresh line starts at 1.
 */
export function matchMarkdownShortcut(
  prefix: string,
  config: NormalizedMarkdownShortcuts
): MarkdownShortcutMatch | null {
  if (prefix.length === 0) {
    return null;
  }
  const first = prefix[0];

  if (first === '#') {
    if (!config.heading || prefix.length > 6 || !/^#+$/.test(prefix)) {
      return null;
    }
    const type = blockTypeForHeadingLevel(prefix.length);
    return type === null ? null : { type, level: prefix.length };
  }

  if (
    prefix.length === 1 &&
    (first === '-' || first === '*' || first === '+')
  ) {
    return config.unorderedList
      ? { type: 'unordered-list-item', level: 0 }
      : null;
  }

  const last = prefix[prefix.length - 1];
  if (
    (last === '.' || last === ')') &&
    prefix.length >= 2 &&
    prefix.length - 1 <= MAX_ORDERED_MARKER_DIGITS &&
    /^[0-9]+$/.test(prefix.slice(0, -1))
  ) {
    return config.orderedList ? { type: 'ordered-list-item', level: 0 } : null;
  }
  return null;
}
