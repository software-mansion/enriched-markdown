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
  // Everything shown is finished: the next block has begun but is still held back (a table's
  // header row, a fence's opening line). Hosts settle what animates at the end of the text then.
  bool showsOnlyFinishedBlocks = false;
  // The source and `markdown` both start with these bytes, which later text
  // can no longer change (finishedBlocksEnd).
  size_t finishedBytes = 0;
};

// The one preparation every streaming consumer runs, so the hosts, their
// measurement and the JS block collector see the same snapshot: the filter,
// then repair, both only on what follows finishedBlocksEnd().
StreamingSnapshot streamingSnapshot(const std::string &source, const StreamingOptions &options);

// Repair options for a stream parsed with `flags`.
RepairOptions streamingRepairOptions(const Md4cFlags &flags);

} // namespace Markdown
