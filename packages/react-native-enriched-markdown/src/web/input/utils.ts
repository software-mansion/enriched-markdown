export function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}

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

export function isWhitespace(char: string): boolean {
  return /\s/.test(char);
}

// Characters outside the 16-bit range (emoji, mostly) occupy two string
// units: a high surrogate (0xD800-0xDBFF) followed by a low one
// (0xDC00-0xDFFF). These ranges never encode standalone characters, so a
// unit's value alone tells whether it is half of a pair.
function isHighSurrogate(code: number): boolean {
  return code >= 0xd800 && code <= 0xdbff;
}

function isLowSurrogate(code: number): boolean {
  return code >= 0xdc00 && code <= 0xdfff;
}

// Deleting half a surrogate pair would corrupt the buffer, so a delete step
// spans the whole pair.
export function backwardStep(text: string, position: number): number {
  return position >= 2 &&
    isLowSurrogate(text.charCodeAt(position - 1)) &&
    isHighSurrogate(text.charCodeAt(position - 2))
    ? 2
    : 1;
}

export function forwardStep(text: string, position: number): number {
  return position + 1 < text.length &&
    isHighSurrogate(text.charCodeAt(position)) &&
    isLowSurrogate(text.charCodeAt(position + 1))
    ? 2
    : 1;
}
