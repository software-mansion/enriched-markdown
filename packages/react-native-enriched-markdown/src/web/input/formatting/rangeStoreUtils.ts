import { firstIndexReachingTarget } from '../utils';
import type { RangeBounds } from '../model/rangeBounds';

// Index at which `location` keeps `ranges` sorted by start; equal starts
// insert after existing entries, so this is the first start past `location`,
// and starts are integer offsets, so that is the first one reaching the next.
export function sortedInsertionIndex(
  ranges: readonly RangeBounds[],
  location: number
): number {
  return firstIndexReachingTarget(
    location + 1,
    ranges.length,
    (index) => ranges[index]!.start
  );
}
