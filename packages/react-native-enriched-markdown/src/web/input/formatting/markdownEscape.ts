// Backslash escapes for plain text written into markdown, so the editor's
// own output re-imports as the text the user typed. Runs on every serialize
// (once per keystroke with `onChangeMarkdown`), so the positions are found in
// one pass over the whole text: a native regex scan plus a few character
// checks per line.
//
// A position does not depend on the delimiters written around it. That
// over-escapes in places ("**\#**" where "**#**" would not have read as a
// heading either), which is harmless: an escaped punctuation character reads
// back as itself anywhere.

const AMPERSAND = 0x26;
const HASH = 0x23;
const DASH = 0x2d;
const PLUS = 0x2b;
const EQUALS = 0x3d;
const GREATER_THAN = 0x3e;
const PERIOD = 0x2e;
const CLOSE_PAREN = 0x29;
const SEMICOLON = 0x3b;
const SPACE = 0x20;
const TAB = 0x09;

const MAX_ORDERED_MARKER_DIGITS = 9;

function isBlank(code: number): boolean {
  return code === SPACE || code === TAB;
}

function isDigit(code: number): boolean {
  return code >= 0x30 && code <= 0x39;
}

function isAlphanumeric(code: number): boolean {
  return (
    isDigit(code) ||
    (code >= 0x41 && code <= 0x5a) ||
    (code >= 0x61 && code <= 0x7a)
  );
}

// "&name;", "&#123;" or "&#x1F;" from `at` (the "&"): md4c would decode it, or
// drop it when the name is unknown.
function startsEntity(text: string, at: number, end: number): boolean {
  let i = at + 1;
  if (i < end && text.charCodeAt(i) === HASH) {
    i++;
  }
  const nameStart = i;
  while (i < end && isAlphanumeric(text.charCodeAt(i))) {
    i++;
  }
  return i > nameStart && i < end && text.charCodeAt(i) === SEMICOLON;
}

// Characters that can open or close a span anywhere in a line. Escaped
// wherever they appear, md4c's flanking rules notwithstanding: the Android
// input completes any unmatched one on import, so an unescaped lone "*" in
// markdown this editor saved would come back there with a closer appended.
// "&" only where it starts an entity (`startsEntity`).
const INLINE_SPECIAL_RE = /[\\`*_~|[\]<&]/g;

// Where a line starting at `start` would read as a block marker - a heading,
// a bullet, a quote, a setext underline or an ordered item's "1." / "1)" -
// the index of the character to escape. "*", "_", "`" and "~" are escaped
// inline already. However deep the indent: import keeps a line's
// leading whitespace as text only when no marker follows it (see
// `protectLeadingWhitespace` in InputParser), so an indented marker the user
// typed has to be escaped to stay text.
function lineStartMarkerAt(text: string, start: number, end: number): number {
  let i = start;
  while (i < end && isBlank(text.charCodeAt(i))) {
    i++;
  }
  if (i === end) {
    return -1;
  }
  const code = text.charCodeAt(i);
  if (
    code === HASH ||
    code === DASH ||
    code === PLUS ||
    code === EQUALS ||
    code === GREATER_THAN
  ) {
    return i;
  }
  const digitsStart = i;
  while (
    i < end &&
    i - digitsStart < MAX_ORDERED_MARKER_DIGITS &&
    isDigit(text.charCodeAt(i))
  ) {
    i++;
  }
  if (i === digitsStart || i === end) {
    return -1;
  }
  const delimiter = text.charCodeAt(i);
  if (delimiter !== PERIOD && delimiter !== CLOSE_PAREN) {
    return -1;
  }
  return i + 1 === end || isBlank(text.charCodeAt(i + 1)) ? i : -1;
}

// A closing sequence an ATX heading would strip - a "#" run ending the line,
// after whitespace or alone - as the index of its first "#".
function trailingHashesAt(text: string, start: number, end: number): number {
  let i = end;
  while (i > start && isBlank(text.charCodeAt(i - 1))) {
    i--;
  }
  const runEnd = i;
  while (i > start && text.charCodeAt(i - 1) === HASH) {
    i--;
  }
  if (i === runEnd) {
    return -1;
  }
  return i === start || isBlank(text.charCodeAt(i - 1)) ? i : -1;
}

// The indices in `text` to put a backslash in front of, ascending.
export function markdownEscapePositions(text: string): number[] {
  const positions: number[] = [];
  INLINE_SPECIAL_RE.lastIndex = 0;
  let inline = INLINE_SPECIAL_RE.exec(text);
  for (let lineStart = 0; lineStart <= text.length; ) {
    let lineEnd = text.indexOf('\n', lineStart);
    if (lineEnd === -1) {
      lineEnd = text.length;
    }
    // In index order: a marker leads its line and a closing "#" run, which
    // holds only "#" and blanks, ends it. Neither is an inline special.
    const marker = lineStartMarkerAt(text, lineStart, lineEnd);
    if (marker !== -1) {
      positions.push(marker);
    }
    for (
      ;
      inline !== null && inline.index < lineEnd;
      inline = INLINE_SPECIAL_RE.exec(text)
    ) {
      const at = inline.index;
      if (
        text.charCodeAt(at) !== AMPERSAND ||
        startsEntity(text, at, lineEnd)
      ) {
        positions.push(at);
      }
    }
    const hashes = trailingHashesAt(text, lineStart, lineEnd);
    if (hashes !== -1 && hashes !== marker) {
      positions.push(hashes);
    }
    lineStart = lineEnd + 1;
  }
  return positions;
}
