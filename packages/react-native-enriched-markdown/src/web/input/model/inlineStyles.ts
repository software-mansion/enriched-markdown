import type { RangeBounds } from './rangeBounds';

// Canonical order for a run's style list, so equal style sets compare equal.
// Any stable order works, but it has to be total: a style missing here is
// filtered out of every run, so the union is derived from it rather than
// declared alongside it.
export const INPUT_STYLE_TYPES = [
  'strong',
  'em',
  'underline',
  'strikethrough',
  'link',
  'spoiler',
] as const;

export type InputStyleType = (typeof INPUT_STYLE_TYPES)[number];

export interface FormattingRange extends RangeBounds {
  type: InputStyleType;
  url?: string;
}

export function createFormattingRange(
  type: InputStyleType,
  start: number,
  end: number,
  url?: string
): FormattingRange {
  return url === undefined ? { type, start, end } : { type, start, end, url };
}
