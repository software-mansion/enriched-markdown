import { isAsciiWhitespace, isWhitespace } from '../utils';

// What sits on one side of a delimiter in the output. A line's edge reads as
// whitespace (a block marker ends in a space), and another delimiter as
// punctuation, which every delimiter character is - except a "*" next to a
// "*", which joins its run (see `isStarDelimiter`).
export type Neighbor = 'whitespace' | 'punctuation' | 'word';

const UNICODE_PUNCTUATION_RE = /[\p{P}\p{S}]/u;

// md4c's classes: CommonMark punctuation is Unicode P and S, so an emoji
// counts as punctuation next to "**".
export function classify(char: string): Neighbor {
  const code = char.charCodeAt(0);
  if (code < 0x80) {
    if (isAsciiWhitespace(code)) {
      return 'whitespace';
    }
    const isAsciiPunctuation =
      (code >= 0x21 && code <= 0x2f) ||
      (code >= 0x3a && code <= 0x40) ||
      (code >= 0x5b && code <= 0x60) ||
      (code >= 0x7b && code <= 0x7e);
    return isAsciiPunctuation ? 'punctuation' : 'word';
  }
  if (isWhitespace(char)) {
    return 'whitespace';
  }
  return UNICODE_PUNCTUATION_RE.test(char) ? 'punctuation' : 'word';
}
