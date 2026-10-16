import type { InputStyleType } from './inlineStyles';

// One end of a formatting range, for sweeps that walk ranges in document
// order: both the projection's run flattening and the serializer's delimiter
// emission.
export interface BoundaryEvent {
  position: number;
  isOpening: boolean;
  type: InputStyleType;
  url: string | undefined;
}

// Ascending by position, and at one position closings come before openings so
// a range ending where another begins never interleaves. Callers that also
// need a defined order among same-direction events at one position pass
// `tieBreak`; those that do not are indifferent to it.
export function compareBoundaryEvents(
  a: BoundaryEvent,
  b: BoundaryEvent,
  tieBreak?: (a: BoundaryEvent, b: BoundaryEvent) => number
): number {
  if (a.position !== b.position) {
    return a.position - b.position;
  }
  if (a.isOpening !== b.isOpening) {
    return a.isOpening ? 1 : -1;
  }
  return tieBreak === undefined ? 0 : tieBreak(a, b);
}
