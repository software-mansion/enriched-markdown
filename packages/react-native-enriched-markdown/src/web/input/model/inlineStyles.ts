import type { RangeBounds } from './rangeBounds';

export type InputStyleType =
  | 'strong'
  | 'em'
  | 'underline'
  | 'strikethrough'
  | 'link'
  | 'spoiler';

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
