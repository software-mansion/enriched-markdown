// Positions are UTF-16 code units into the plain-text buffer
// `start` inclusive, `end` exclusive.
export interface RangeBounds {
  start: number;
  end: number;
}
