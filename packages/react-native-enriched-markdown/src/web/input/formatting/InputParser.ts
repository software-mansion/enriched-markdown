import { loadParser } from '../../parseMarkdown';
import type { BlockRange } from '../model/blocks';
import type { FormattingRange } from '../model/inlineStyles';
import { parseWithCore } from './inputCore';

export interface ParseResult {
  plainText: string;
  formattingRanges: FormattingRange[];
  blockRanges: BlockRange[];
}

// The import itself is the C++ core's (cpp/input), reached through the WASM
// module. The markdown is parsed as given: an unclosed delimiter stays literal
// text, since completing it first would turn the lone `_` of `snake_case`, the
// `*` of `2*3` or a `[` into formatting or into text the caller never passed.
// Syntax the input has no model for (quotes, code, tables, rules) loses its
// markers and keeps its content, and bare URLs stay plain text until the
// autolink layer claims them. Ordinals and list depths come back settled, as
// the block store would leave them.
export async function parseToPlainTextAndRanges(
  markdown: string
): Promise<ParseResult> {
  if (markdown.length === 0) {
    return { plainText: '', formattingRanges: [], blockRanges: [] };
  }
  try {
    await loadParser();
    return parseWithCore(markdown);
  } catch {
    // A library must not crash the host app when the WASM module is
    // unavailable: the markdown stays as plain text.
    return { plainText: markdown, formattingRanges: [], blockRanges: [] };
  }
}
