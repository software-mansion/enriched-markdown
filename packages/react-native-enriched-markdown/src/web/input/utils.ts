// Kotlin's coerceIn: clamps `value` into [min, max].
export function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}
