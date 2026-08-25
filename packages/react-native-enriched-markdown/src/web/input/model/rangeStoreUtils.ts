import type { RangeBounds } from './types';

// Index at which `location` keeps `ranges` sorted by start; equal starts
// insert after existing entries.
export function sortedInsertionIndex(
  ranges: readonly RangeBounds[],
  location: number
): number {
  let index = 0;
  for (const existing of ranges) {
    if (existing.start > location) {
      break;
    }
    index++;
  }
  return index;
}
