import { firstIndexReachingTarget } from '../utils';
import type { RangeBounds } from '../model/rangeBounds';

// Equal starts insert after existing entries: the first start past
// `location`, which for integer offsets is the first one reaching the next.
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
