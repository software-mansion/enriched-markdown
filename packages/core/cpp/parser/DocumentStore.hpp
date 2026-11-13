#pragma once

#include "BlockSlots.hpp"
#include "MD4CParser.hpp"
#include "MarkdownASTNode.hpp"
#include "StreamingSession.hpp"
#include <atomic>
#include <cstddef>
#include <list>
#include <memory>
#include <mutex>
#include <string>
#include <unordered_set>
#include <vector>

namespace Markdown {

// One parsed document, shared read-only by every caller that asks for the same
// text and options: the JS block collector, the shadow node's measurement and
// the view's render. Nothing writes to the tree after the parse; hosts add slot
// ids and recognized links while converting it (AstOverlay).
struct ParsedDocument {
  std::shared_ptr<const MarkdownASTNode> ast; // null for an empty document
  CollectedBlocks blocks;
};

// The blocks at the start of a streamed document that later text can no longer change, parsed once:
// every later state of the stream shares these nodes and parses only what follows them.
struct FinishedBlocks {
  size_t bytes = 0; // the document's first bytes they were parsed from
  std::vector<std::shared_ptr<MarkdownASTNode>> nodes;
  BlockCollector collector;
  // False once the parser disagreed that the blocks end there: the stream is parsed whole from then on.
  bool extendable = true;
};

// How many of `a`'s first top-level blocks are the very nodes `b` starts with: the finished blocks
// two states of a stream share, whose conversions a host can take over.
size_t sharedLeadingBlocks(const ParsedDocument &a, const ParsedDocument &b);

// As above, for conversions made with different active slots (`aSlots` for `a`, `bSlots` for `b`): up to
// the first block holding a slot only one of them has, since a conversion carries an active slot's id.
size_t sharedLeadingBlocks(const ParsedDocument &a, const ParsedDocument &b,
                           const std::unordered_set<std::string> &aSlots,
                           const std::unordered_set<std::string> &bSlots);

// A streaming snapshot or parse is computed once per input and process: a
// tick's collect on the JS thread, measurement on the layout thread and the
// render on the main or a background thread all ask for the same text one
// after another. Thread-safe; a miss is only slower, never different.
//
// A snapshot's text is parsed in two parts: the blocks before its finishedBytes
// once per stream (FinishedBlocks), the rest on every update. The result is the
// tree a whole parse gives; the nodes of the finished blocks are the same
// objects from one update to the next, which the hosts use to convert and
// render only what is new.
class DocumentStore {
public:
  static DocumentStore &shared();

  StreamingSnapshot snapshot(const std::string &markdown, const StreamingOptions &options);
  std::shared_ptr<const ParsedDocument> parse(const std::string &markdown, const Md4cFlags &flags, bool isGFM);

  // How many snapshots and parses actually ran, for tests and debugging.
  size_t snapshotCount() const {
    return snapshotsRun_;
  }
  size_t parseCount() const {
    return parses_;
  }
  // How many of the parses reused a stream's finished blocks.
  size_t extendedParseCount() const {
    return extendedParses_;
  }
  void clear();

private:
  struct SnapshotEntry {
    std::string markdown;
    StreamingOptions options;
    StreamingSnapshot snapshot;
  };
  struct DocumentEntry {
    std::string markdown;
    Md4cFlags flags;
    bool isGFM;
    std::shared_ptr<const ParsedDocument> document;
    std::shared_ptr<const FinishedBlocks> finished; // null for a document parsed whole
  };
  struct Parsed {
    std::shared_ptr<ParsedDocument> document;
    std::shared_ptr<const FinishedBlocks> finished;
  };
  Parsed parseStreamed(const std::string &markdown, size_t finishedBytes,
                       std::shared_ptr<const FinishedBlocks> finished, const Md4cFlags &flags, bool isGFM);

  std::mutex mutex_;
  std::list<SnapshotEntry> snapshots_; // most recent first
  std::list<DocumentEntry> documents_; // most recent first
  size_t snapshotBytes_ = 0;
  size_t documentBytes_ = 0;
  std::atomic<size_t> snapshotsRun_{0};
  std::atomic<size_t> parses_{0};
  std::atomic<size_t> extendedParses_{0};
};

} // namespace Markdown
