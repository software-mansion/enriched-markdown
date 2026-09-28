import type { RangeBounds } from '../model/rangeBounds';

// Index at which `location` keeps `ranges` sorted by start; equal starts
// insert after existing entries.
export function sortedInsertionIndex(
  ranges: readonly RangeBounds[],
  location: number
): number {
  let low = 0;
  let high = ranges.length;
  while (low < high) {
    const mid = Math.floor((low + high) / 2);
    if (ranges[mid]!.start > location) {
      high = mid;
    } else {
      low = mid + 1;
    }
  }
  return low;
}
