#pragma once

#include "BlockSlots.hpp"
#include "MD4CParser.hpp"
#include "MarkdownASTNode.hpp"
#include "StreamingFilter.hpp"
#include <atomic>
#include <cstddef>
#include <list>
#include <memory>
#include <mutex>
#include <string>

namespace Markdown {

// One parsed document, shared read-only by every caller that asks for the same
// text and options: the JS block collector, the shadow node's measurement and
// the view's render. Nothing writes to the tree after the parse; hosts add slot
// ids and recognized links while converting it (AstOverlay).
struct ParsedDocument {
  std::shared_ptr<const MarkdownASTNode> ast; // null for an empty document
  CollectedBlocks blocks;
};

// A streaming filter or parse is computed once per input and process: a tick's
// collect on the JS thread, measurement on the layout thread and the render on
// the main or a background thread all ask for the same text one after another.
// Thread-safe; a miss is only slower, never different.
class DocumentStore {
public:
  static DocumentStore &shared();

  StreamingFilterResult filter(const std::string &markdown, const StreamingFilterOptions &options);
  std::shared_ptr<const ParsedDocument> parse(const std::string &markdown, const Md4cFlags &flags, bool isGFM);

  // How many filters and parses actually ran, for tests and debugging.
  size_t filterCount() const {
    return filters_;
  }
  size_t parseCount() const {
    return parses_;
  }
  void clear();

private:
  struct FilterEntry {
    std::string markdown;
    StreamingFilterOptions options;
    StreamingFilterResult result;
  };
  struct DocumentEntry {
    std::string markdown;
    Md4cFlags flags;
    bool isGFM;
    std::shared_ptr<const ParsedDocument> document;
  };

  std::mutex mutex_;
  std::list<FilterEntry> filtered_;    // most recent first
  std::list<DocumentEntry> documents_; // most recent first
  size_t filteredBytes_ = 0;
  size_t documentBytes_ = 0;
  std::atomic<size_t> filters_{0};
  std::atomic<size_t> parses_{0};
};

} // namespace Markdown
