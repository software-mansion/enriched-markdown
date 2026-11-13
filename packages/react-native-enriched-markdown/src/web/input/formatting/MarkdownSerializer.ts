import type { BlockRange } from '../model/blocks';
import type { FormattingRange } from '../model/inlineStyles';
import { isInputCoreLoaded, serializeWithCore } from './inputCore';

// The export itself is the C++ core's (cpp/input), reached through the WASM
// module: delimiters, block markers and the escaping of plain text that would
// read as markup are all written there.

/**
 * Plain text and ranges to markdown. Blocks come one per line. Throws until
 * the WASM module has loaded: callers that cannot wait use
 * {@link serializeOrPlainText}.
 */
export function serialize(
  text: string,
  ranges: readonly FormattingRange[],
  blockRanges: readonly BlockRange[]
): string {
  return serializeWithCore(text, ranges, blockRanges);
}

/** {@link serialize} for text with styles and no blocks. */
export function serializeInline(
  text: string,
  ranges: readonly FormattingRange[]
): string {
  return serializeWithCore(text, ranges, []);
}

let warnedAboutPlainText = false;

/**
 * For callers that cannot wait for the module (`getMarkdown`, the copy
 * handler): the markdown once it has loaded, otherwise - still loading, or the
 * load failed - the plain text without markers, with one warning.
 */
export function serializeOrPlainText(
  text: string,
  ranges: readonly FormattingRange[],
  blockRanges: readonly BlockRange[]
): string {
  if (isInputCoreLoaded()) {
    return serializeWithCore(text, ranges, blockRanges);
  }
  if (!warnedAboutPlainText) {
    warnedAboutPlainText = true;
    console.warn(
      'react-native-enriched-markdown: the markdown core is not loaded (yet), so the markdown is returned without formatting. It loads when the input mounts; wait for onChangeMarkdown, or call getMarkdown later.'
    );
  }
  return text;
}
