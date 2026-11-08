#pragma once

#include "MD4CParser.hpp"
#include "StreamingFilter.hpp"
#include <cstddef>
#include <string>

namespace Markdown {

struct RepairOptions; // MarkdownRepair.hpp

// What a streamed document is prepared with: the block modes the filter takes
// and the parser's flags, which decide how repair reads `$`, `^`, `~` and `==`.
struct StreamingOptions {
  StreamingFilterOptions blocks;
  Md4cFlags flags;

  bool operator==(const StreamingOptions &other) const {
    return blocks == other.blocks && flags == other.flags;
  }
};

struct StreamingSnapshot {
  // What to parse and render for this state of the stream.
  std::string markdown;
  // See StreamingFilterResult.
  bool endsInsideOpenCodeFence = false;
  // The source and `markdown` both start with these bytes: the blocks that
  // later text can no longer change (finishedBlocksEnd).
  size_t finishedBytes = 0;
};

// The one preparation every streaming consumer runs on a document that is
// still arriving (the iOS and Android hosts, their view-free measurement and
// the JS block collector), so they all see the same snapshot:
//
//   1. the blocks before finishedBlocksEnd() stay as they are;
//   2. the filter withholds the trailing blocks that have not finished
//      arriving (tables, fences, media, `$$` math);
//   3. repair, with streamingRepairOptions(), handles inline syntax still
//      being typed: emphasis and code get their closers, a link shows its
//      label as text until its URL closes, and an image, unclosed math or a
//      lone marker line waits.
//
// The work after the first step is proportional to the unfinished tail.
StreamingSnapshot streamingSnapshot(const std::string &source, const StreamingOptions &options);

// Repair options for a stream parsed with `flags`.
RepairOptions streamingRepairOptions(const Md4cFlags &flags);

} // namespace Markdown
