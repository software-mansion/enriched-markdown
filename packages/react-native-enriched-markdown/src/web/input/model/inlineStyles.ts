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

// A style that can be armed at the caret and applied to the next insert. A
// link cannot: it carries a url that a pending style has nowhere to keep, and
// `FormattingStore.addRange` takes the new range's url, so a pending `link`
// would strip the url from whatever it merged with. Android encodes the same
// exclusion when it seeds its pending styles; expressing it in the type means
// web cannot reach that state at all.
export type PendingStyleType = Exclude<InputStyleType, 'link'>;

export const TYPING_ATTRIBUTE_STYLES: readonly PendingStyleType[] = [
  'strong',
  'em',
  'underline',
  'strikethrough',
  'spoiler',
];

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
