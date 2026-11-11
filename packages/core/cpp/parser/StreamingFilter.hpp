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

// The pre-parse filter every streaming consumer runs (the iOS and Android hosts,
// their view-free measurement and the JS block collector), so they all see the
// same document while it streams. It hides what has not finished arriving:
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

// Where the blocks that later text can no longer change end: the start of the
// last line that begins a top-level block after a blank line, outside fenced
// code, `$$` math and HTML blocks that may hold blank lines; 0 when there is
// none. A line still arriving counts once it can no longer become one of those. The filter and repair act only on what follows it, so appending text
// never changes the part before it.
size_t finishedBlocksEnd(std::string_view markdown, bool latexMath = true);

StreamingBlockMode streamingBlockModeFromName(const std::string &name); // "hidden" | anything else

} // namespace Markdown
