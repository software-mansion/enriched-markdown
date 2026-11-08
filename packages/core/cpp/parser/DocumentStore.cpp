#include "DocumentStore.hpp"

namespace Markdown {

namespace {

// Several messages of a chat can stream or measure in one commit.
constexpr size_t kMaxEntries = 16;
// The tree and its strings take several times the Markdown's size. Past the
// budget the oldest entries go; the newest always stays, so the callers of one
// tick share even a document larger than the budget.
constexpr size_t kTreeBytesPerByte = 8;
constexpr size_t kBudgetBytes = 8 * 1024 * 1024;

// Moves the first matching entry to the front; whether there was one.
template <typename Entry, typename Matches> bool moveToFront(std::list<Entry> &entries, Matches matches) {
  for (auto it = entries.begin(); it != entries.end(); ++it) {
    if (matches(*it)) {
      entries.splice(entries.begin(), entries, it);
      return true;
    }
  }
  return false;
}

// Drops the oldest entries past the count or byte budget, keeping the newest.
template <typename Entry, typename Bytes> void evict(std::list<Entry> &entries, size_t &totalBytes, Bytes bytes) {
  while (entries.size() > 1 && (entries.size() > kMaxEntries || totalBytes > kBudgetBytes)) {
    totalBytes -= bytes(entries.back());
    entries.pop_back();
  }
}

size_t snapshotBytes(const std::string &markdown, const StreamingSnapshot &snapshot) {
  return markdown.size() + snapshot.markdown.size();
}

} // namespace

DocumentStore &DocumentStore::shared() {
  static DocumentStore store;
  return store;
}

StreamingSnapshot DocumentStore::snapshot(const std::string &markdown, const StreamingOptions &options) {
  auto matches = [&](const SnapshotEntry &entry) { return entry.options == options && entry.markdown == markdown; };
  {
    std::lock_guard<std::mutex> lock(mutex_);
    if (moveToFront(snapshots_, matches))
      return snapshots_.front().snapshot;
  }

  // Prepared outside the lock; if another thread did the same meanwhile, the
  // first one stored wins.
  snapshotsRun_++;
  StreamingSnapshot snapshot = streamingSnapshot(markdown, options);
  std::lock_guard<std::mutex> lock(mutex_);
  if (moveToFront(snapshots_, matches))
    return snapshots_.front().snapshot;
  snapshots_.push_front({markdown, options, snapshot});
  snapshotBytes_ += snapshotBytes(markdown, snapshot);
  evict(snapshots_, snapshotBytes_,
        [](const SnapshotEntry &entry) { return snapshotBytes(entry.markdown, entry.snapshot); });
  return snapshot;
}

std::shared_ptr<const ParsedDocument> DocumentStore::parse(const std::string &markdown, const Md4cFlags &flags,
                                                           bool isGFM) {
  auto matches = [&](const DocumentEntry &entry) {
    return entry.isGFM == isGFM && entry.flags == flags && entry.markdown == markdown;
  };
  {
    std::lock_guard<std::mutex> lock(mutex_);
    if (moveToFront(documents_, matches))
      return documents_.front().document;
  }

  // Parsed outside the lock; if another thread parsed the same text meanwhile,
  // the first one stored wins so every caller shares one tree.
  parses_++;
  auto document = std::make_shared<ParsedDocument>();
  if (!markdown.empty()) {
    std::shared_ptr<MarkdownASTNode> ast = MD4CParser().parse(markdown, flags, isGFM);
    if (ast)
      document->blocks = collect(*ast);
    document->ast = std::move(ast);
  }

  std::lock_guard<std::mutex> lock(mutex_);
  if (moveToFront(documents_, matches))
    return documents_.front().document;
  documents_.push_front({markdown, flags, isGFM, document});
  documentBytes_ += markdown.size() * kTreeBytesPerByte;
  evict(documents_, documentBytes_,
        [](const DocumentEntry &entry) { return entry.markdown.size() * kTreeBytesPerByte; });
  return document;
}

void DocumentStore::clear() {
  std::lock_guard<std::mutex> lock(mutex_);
  snapshots_.clear();
  documents_.clear();
  snapshotBytes_ = 0;
  documentBytes_ = 0;
  snapshotsRun_ = 0;
  parses_ = 0;
}

} // namespace Markdown
