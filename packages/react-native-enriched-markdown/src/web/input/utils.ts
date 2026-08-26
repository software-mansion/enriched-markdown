export function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}

export function isWhitespace(char: string): boolean {
  return /\s/.test(char);
}
