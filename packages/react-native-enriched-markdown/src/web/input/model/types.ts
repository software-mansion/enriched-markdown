export type InputStyleType =
  | 'strong'
  | 'em'
  | 'underline'
  | 'strikethrough'
  | 'link'
  | 'spoiler';

// Positions are UTF-16 code units into the plain-text buffer
// `start` inclusive, `end` exclusive.
export interface RangeBounds {
  start: number;
  end: number;
}

export interface FormattingRange extends RangeBounds {
  type: InputStyleType;
  url?: string;
}
