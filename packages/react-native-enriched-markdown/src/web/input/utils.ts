// Kotlin's coerceIn: clamps `value` into [min, max].
export function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}

// Leftmost index whose value reaches `target`, or `size` when none does, over
// a collection whose values rise with the index. The stores keep their ranges
// sorted, so every lookup into them is one of these rather than a scan.
export function firstIndexReachingTarget(
  target: number,
  size: number,
  valueAt: (index: number) => number
): number {
  let low = 0;
  let high = size;
  while (low < high) {
    const mid = Math.floor((low + high) / 2);
    if (valueAt(mid) < target) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }
  return low;
}
