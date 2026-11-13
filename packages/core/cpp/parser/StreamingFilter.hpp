#pragma once

#include <string>
#include <string_view>

namespace Markdown {

enum class StreamingBlockMode { Hidden, Progressive };

struct StreamingFilterOptions {
  StreamingBlockMode tableMode = StreamingBlockMode::Progressive;
  StreamingBlockMode codeBlockMode = StreamingBlockMode::Progressive;
  StreamingBlockMode mediaMode = StreamingBlockMode::Progressive;

  bool operator==(const StreamingFilterOptions &other) const {
    return tableMode == other.tableMode && codeBlockMode == other.codeBlockMode && mediaMode == other.mediaMode;
  }
};

struct StreamingFilterResult {
  std::string markdown;
  // The result ends inside a fenced code block whose closing fence has not
  // arrived (the trailing block whose highlighting and copy chrome the
  // renderer defers). Only possible with codeBlockMode Progressive.
  bool endsInsideOpenCodeFence = false;
};

// The pre-parse filter the streaming session runs on the unfinished tail
// (StreamingSession.hpp), which every host, measurement and the JS block
// collector share. It hides what has not finished arriving:
//
//   * block math, with `latexMath`: an unterminated `$$` block is cut at its
//     opening delimiter;
//   * tables: Hidden withholds a trailing table until a blank line follows it,
//     Progressive trims an incomplete trailing row;
//   * fenced code: Hidden cuts an open fence, Progressive keeps it once its
//     opening line has ended and filters only the text before it;
//   * media (a trailing image paragraph, link-only paragraph or `<video>`
//     block, the blocks a renderer can replace): Hidden withholds it
//     until a blank line or another block follows, Progressive withholds it only
//     while its syntax is still open.
//
// It owns blocks only; inline syntax still being typed is repair's
// (StreamingSession.hpp).
StreamingFilterResult renderableMarkdownForStreaming(const std::string &markdown, const StreamingFilterOptions &options,
                                                     bool latexMath = true);

// Where the bytes that later text can no longer change end: the start of the
// last line that begins a top-level block after a blank line, outside fenced
// code, `$$` math and HTML blocks that may hold blank lines; 0 when there is
// none. A line still arriving counts once it can no longer become one of
// those, except a quote line, which can still turn into a code fence inside
// the quote and move the end back. The filter and repair act only on what
// follows it, so appending text never changes the bytes before it (their
// parse may still change: a later `[r]: url` turns `[docs][r]` into a link).
size_t finishedBlocksEnd(std::string_view markdown, bool latexMath = true);

// Whether a line that follows a blank line at the top level starts a block of its own, whatever came
// before it: not indented, and no list marker, reference definition, footnote or HTML that could
// belong to the block above. finishedBlocksEnd() ends at such a line.
bool startsTopLevelBlock(std::string_view line);

// Whether a line of `markdown` could start a link reference definition (`[label]: url`), the one
// syntax that changes how blocks before and after it parse. Errs on the side of true: only the code of
// a fence at the start of a line is skipped; other code that looks like one counts.
bool mayDefineLinkReference(std::string_view markdown);

StreamingBlockMode streamingBlockModeFromName(const std::string &name); // "hidden" | anything else

} // namespace Markdown
