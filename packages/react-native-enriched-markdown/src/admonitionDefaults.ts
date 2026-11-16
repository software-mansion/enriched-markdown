import { useMemo } from 'react';
import { normalizeColor } from './styleUtils';
import type { AdmonitionsStyle } from './types/MarkdownStyle';
import type { MarkdownStyleInternal } from './types/MarkdownStyleInternal';
import type {
  AdmonitionTitles,
  AdmonitionType,
} from './types/admonitionTitles';

export type { AdmonitionTitles, AdmonitionType };

// The five GitHub-flavored admonition/alert types, in the order md4c reports
// them (see MD_ADMONITION_TAGS). The `admonitionType` attribute emitted by the
// parser is always one of these lowercase strings.
export const ADMONITION_TYPES = [
  'note',
  'tip',
  'important',
  'warning',
  'caution',
] as const satisfies readonly AdmonitionType[];

export const DEFAULT_ADMONITION_TITLES: Readonly<
  Record<AdmonitionType, string>
> = Object.freeze({
  note: 'Note',
  tip: 'Tip',
  important: 'Important',
  warning: 'Warning',
  caution: 'Caution',
});

// GitHub alert palette. Each `color` tints the left accent bar, the title label
// and the icon for that type. Backgrounds default to transparent (no fill) per
// the issue; users opt into a tint via markdownStyle.blockquote.admonitions.
const ADMONITION_COLOR_DEFAULTS: Record<AdmonitionType, string> = {
  note: '#0969DA',
  tip: '#1A7F37',
  important: '#8250DF',
  warning: '#9A6700',
  caution: '#CF222E',
};

export interface ResolvedAdmonition {
  color: string;
  backgroundColor: string;
  title: string;
}

export type ResolvedAdmonitions = Record<AdmonitionType, ResolvedAdmonition>;

// Merge user overrides over the GitHub defaults and normalize every color, so
// native/web receive a complete, concrete per-type palette plus the default
// title (useAdmonitionTitles replaces it). Mirrors the linkVariants resolution:
// `color` falls back to the type default, and an empty or omitted
// `backgroundColor` resolves to transparent (drawn as no fill).
export function resolveAdmonitions(
  user: AdmonitionsStyle | undefined
): ResolvedAdmonitions {
  const transparent = normalizeColor('transparent')! as string;
  const result = {} as ResolvedAdmonitions;
  for (const type of ADMONITION_TYPES) {
    const override = user?.[type];
    result[type] = {
      color: ((override?.color ? normalizeColor(override.color) : undefined) ??
        normalizeColor(ADMONITION_COLOR_DEFAULTS[type])!) as string,
      backgroundColor: (override?.backgroundColor
        ? (normalizeColor(override.backgroundColor) ?? transparent)
        : transparent) as string,
      title: DEFAULT_ADMONITION_TITLES[type],
    };
  }
  return result;
}

// The header draws one line, so line breaks in a title become spaces.
const LINE_BREAKS = /[\r\n\u0085\u2028\u2029]+/g;

// Titles ride in the style because native draws the header from it. Returns
// `style` itself when no title changes.
function applyAdmonitionTitles(
  style: MarkdownStyleInternal,
  titles: AdmonitionTitles | undefined
): MarkdownStyleInternal {
  const current = style.blockquote.admonitions;
  let admonitions: MarkdownStyleInternal['blockquote']['admonitions'] | null =
    null;
  for (const type of ADMONITION_TYPES) {
    const title = (titles?.[type] ?? DEFAULT_ADMONITION_TITLES[type])
      .replace(LINE_BREAKS, ' ')
      .trim();
    if (title === current[type].title) continue;
    admonitions ??= { ...current };
    admonitions[type] = { ...current[type], title };
  }
  if (admonitions == null) return style;
  return Object.freeze({
    ...style,
    blockquote: { ...style.blockquote, admonitions },
  });
}

// Memoized on the strings, so an inline `admonitionTitles` literal is stable.
export function useAdmonitionTitles(
  style: MarkdownStyleInternal,
  titles: AdmonitionTitles | undefined
): MarkdownStyleInternal {
  const note = titles?.note;
  const tip = titles?.tip;
  const important = titles?.important;
  const warning = titles?.warning;
  const caution = titles?.caution;
  return useMemo(
    () =>
      applyAdmonitionTitles(style, { note, tip, important, warning, caution }),
    [style, note, tip, important, warning, caution]
  );
}
