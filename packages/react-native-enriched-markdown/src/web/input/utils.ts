// Kotlin's coerceIn: clamps `value` into [min, max].
export function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}

// Leftmost index whose value reaches `target`, or `size` when none does, over
// a collection whose values rise with the index: sorted insertion points and
// BlockStore's line lookup. FormattingStore's queries scan instead - ranges of
// other types interleave and a covering range can start far back - but stop
// at the first range starting past the position.
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

// Nearest code point boundary at or before `index`. A surrogate pair is two
// units wide, so one step back always reaches a boundary. Every offset that
// enters the model goes through this or through `graphemeLength*`: clamping an
// offset into the buffer's bounds is not enough on its own, because the seam
// inside a surrogate pair is in bounds, and an edit there splits the pair into
// two lone surrogates.
export function codePointBoundaryAtOrBefore(
  text: string,
  index: number
): number {
  return isCodePointBoundary(text, index) ? index : index - 1;
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
//
// Segmentation starts at the line start, the nearest known boundary: from
// the middle of a run of flags it pairs regional indicators wrongly.
export function graphemeLengthBefore(text: string, position: number): number {
  if (position <= 0) {
    return 0;
  }
  if (text[position - 1] === '\n') {
    return 1;
  }
  if (graphemeSegmenter === null) {
    return codePointLengthBefore(text, position);
  }
  const lineStart = text.lastIndexOf('\n', position - 1) + 1;
  let lastBoundary = 0;
  for (const { index } of graphemeSegmenter.segment(
    text.slice(lineStart, position)
  )) {
    lastBoundary = index;
  }
  return position - (lineStart + lastBoundary);
}

// `position` is a caret, and so already a boundary; the next one is where
// the first segment from it ends.
export function graphemeLengthAfter(text: string, position: number): number {
  if (position >= text.length) {
    return 0;
  }
  if (text[position] === '\n') {
    return 1;
  }
  if (graphemeSegmenter === null) {
    return codePointLengthAfter(text, position);
  }
  const lineEnd = text.indexOf('\n', position);
  const slice = text.slice(position, lineEnd === -1 ? text.length : lineEnd);
  let seenFirst = false;
  for (const { index } of graphemeSegmenter.segment(slice)) {
    if (seenFirst) {
      return index;
    }
    seenFirst = true;
  }
  return slice.length;
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
