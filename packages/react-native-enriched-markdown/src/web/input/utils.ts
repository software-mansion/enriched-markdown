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

export function isWhitespace(char: string): boolean {
  return /\s/.test(char);
}

// Code points outside the 16-bit range (emoji, mostly) occupy two string
// units: a high surrogate (0xD800-0xDBFF) followed by a low one
// (0xDC00-0xDFFF). These ranges never encode standalone code points, so a
// unit's value alone tells whether it is half of a pair.
function isHighSurrogate(code: number): boolean {
  return code >= 0xd800 && code <= 0xdbff;
}

function isLowSurrogate(code: number): boolean {
  return code >= 0xdc00 && code <= 0xdfff;
}

// True when `index` is a code point boundary rather than the seam inside a
// surrogate pair. Every offset the stores hold has to be one of these: half a
// pair on each side of an edit is not text.
export function isCodePointBoundary(text: string, index: number): boolean {
  return !(
    isLowSurrogate(text.charCodeAt(index)) &&
    isHighSurrogate(text.charCodeAt(index - 1))
  );
}

// `Intl.Segmenter` is the only API that segments by user-perceived character.
// Typed as optional and resolved once: Chrome/Edge 87+, Safari 14.1+ and
// Firefox 125+ have it; older runtimes fall back to code point stepping.
interface GraphemeSegmenter {
  segment(input: string): Iterable<{ index: number }>;
}

const graphemeSegmenter: GraphemeSegmenter | null = (() => {
  const IntlRef = Intl as unknown as {
    Segmenter?: new (
      locales?: string | string[],
      options?: { granularity?: 'grapheme' | 'word' | 'sentence' }
    ) => GraphemeSegmenter;
  };
  if (typeof IntlRef.Segmenter !== 'function') {
    return null;
  }
  try {
    return new IntlRef.Segmenter(undefined, { granularity: 'grapheme' });
  } catch {
    return null;
  }
})();

// A cluster has no length limit in principle (a ZWJ chain can run as long as
// it likes), so segmentation runs over a window and widens only when the
// window turns out to be one unbroken cluster.
const GRAPHEME_WINDOW = 64;

// Length in UTF-16 units of the grapheme cluster before/after `position`, or
// 0 at the respective end of the buffer.
//
// One delete step is one user-perceived character, which is a cluster and not
// a code point: an emoji with a variation selector ("❤️"), a letter
// with a combining mark, a flag's two regional indicators and a ZWJ sequence
// each go in a single step. Both natives get this by delegating to the
// platform and measuring the diff afterwards (iOS falls through to
// `-[UITextView deleteBackward]`, Android to `deleteSurroundingText`, whose
// backspace uses `TextUtils.getOffsetBefore`); web has to compute the step
// itself, so it segments instead.
export function graphemeLengthBefore(text: string, position: number): number {
  if (position <= 0) {
    return 0;
  }
  if (graphemeSegmenter === null) {
    return codePointLengthBefore(text, position);
  }
  for (let window = GRAPHEME_WINDOW; ; window *= 2) {
    const from = Math.max(position - window, 0);
    let lastBoundary = 0;
    for (const { index } of graphemeSegmenter.segment(
      text.slice(from, position)
    )) {
      lastBoundary = index;
    }
    // A window that holds no boundary past its own start is one cluster, so
    // the real boundary may lie further back; widen unless the whole prefix
    // is already in view.
    if (lastBoundary > 0 || from === 0) {
      return position - (from + lastBoundary);
    }
  }
}

export function graphemeLengthAfter(text: string, position: number): number {
  if (position >= text.length) {
    return 0;
  }
  if (graphemeSegmenter === null) {
    return codePointLengthAfter(text, position);
  }
  for (let window = GRAPHEME_WINDOW; ; window *= 2) {
    const to = Math.min(position + window, text.length);
    const slice = text.slice(position, to);
    let nextBoundary = slice.length;
    let seenFirst = false;
    for (const { index } of graphemeSegmenter.segment(slice)) {
      if (seenFirst) {
        nextBoundary = index;
        break;
      }
      seenFirst = true;
    }
    if (nextBoundary < slice.length || to === text.length) {
      return nextBoundary;
    }
  }
}

function codePointLengthBefore(text: string, position: number): number {
  return isCodePointBoundary(text, position - 1) ? 1 : 2;
}

function codePointLengthAfter(text: string, position: number): number {
  return position + 1 < text.length &&
    isHighSurrogate(text.charCodeAt(position)) &&
    isLowSurrogate(text.charCodeAt(position + 1))
    ? 2
    : 1;
}
