#pragma once

#include "MarkdownRepair.hpp"
#include "StreamingFilter.hpp"
#include <cstdint>
#include <string>
#include <string_view>

namespace Markdown {

struct StreamingSessionOptions {
  RepairOptions repair;
  // false renders the whole document on every update (md4c's preserveBlankLines).
  bool cutBlocks = true;
};

// One update of a streaming document, in bytes of the markdown the host passed.
// The host renders [frozenBytes, frozenBytes + finishedBytes) once and keeps it,
// then renders `tail` after it. A finished chunk is a prefix of the markdown;
// the tail is filtered and repaired, so its text is not.
struct StreamingUpdate {
  uint64_t lineage = 0;     // changes when the markdown no longer extends the frozen text
  size_t frozenBytes = 0;   // rendered and kept before this update; smaller than before only after restartOpenList
  size_t finishedBytes = 0; // finishes with this update; 0 when nothing does
  bool finishedContinuesList = false;   // the finished chunk's first block goes on with the frozen list
  bool finishedContinuedByTail = false; // the finished chunk's last list goes on in the tail
  std::string tail;
  bool tailContinuesList = false;
  bool tailEndsInsideOpenCodeFence = false;
  size_t tailCodeBodyStart = std::string::npos; // the body of the tail's open top-level fence; parse the tail up to it
};

// The streaming engine every host shares: which blocks of a growing document
// are finished, which lines of the rest to show, and how a list continues across
// the cut. The host passes the whole markdown on every update. One session per
// document, used from one thread at a time.
class StreamingSession {
public:
  explicit StreamingSession(StreamingSessionOptions options = {});

  StreamingUpdate update(std::string_view markdown, const StreamingFilterOptions &filter);

  // The host could not continue the frozen list, e.g. a wider number widened its
  // marker column: forget the frozen items back to the list's start and render
  // the list whole this time.
  StreamingUpdate restartOpenList(std::string_view markdown, const StreamingFilterOptions &filter);

private:
  StreamingUpdate update(std::string_view markdown, const StreamingFilterOptions &filter, bool cuttingLists);
  void reset();

  StreamingSessionOptions options_;
  uint64_t lineage_;
  std::string frozen_;
  bool continuesList_ = false;
  size_t listAnchor_ = std::string::npos;
  bool rendersWhole_;
};

} // namespace Markdown
