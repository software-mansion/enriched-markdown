#pragma once

#include <string>

namespace Markdown {

enum class StreamingBlockMode { Hidden, Progressive };

struct StreamingFilterOptions {
  StreamingBlockMode tableMode = StreamingBlockMode::Progressive;
  StreamingBlockMode codeBlockMode = StreamingBlockMode::Progressive;
  StreamingBlockMode mediaMode = StreamingBlockMode::Progressive;
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
//   * block math: an unterminated `$$` block is cut at its opening delimiter;
//   * tables: Hidden withholds a trailing table until a blank line follows it,
//     Progressive trims an incomplete trailing row;
//   * fenced code: Hidden cuts an open fence, Progressive keeps it and filters
//     only the text before it;
//   * media (an image paragraph, a link-only paragraph or a `<video>` block on
//     the last line, the blocks a renderer can replace): Hidden withholds it
//     until a blank line or another block follows, Progressive withholds it only
//     while its syntax is still open;
//   * an inline image or link still being typed at the end of the last
//     paragraph (`text ![alt](https://`) is cut so it never shows as text.
StreamingFilterResult renderableMarkdownForStreaming(const std::string &markdown,
                                                     const StreamingFilterOptions &options);

StreamingBlockMode streamingBlockModeFromName(const std::string &name); // "hidden" | anything else

} // namespace Markdown
