#include "DocumentStore.hpp"
#include "StreamingFilter.hpp"
#include "TextScan.hpp"
#include <string_view>

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

std::shared_ptr<ParsedDocument> parseWhole(const std::string &markdown, const Md4cFlags &flags, bool isGFM) {
  auto document = std::make_shared<ParsedDocument>();
  if (!markdown.empty()) {
    std::shared_ptr<MarkdownASTNode> ast = MD4CParser().parse(markdown, flags, isGFM);
    if (ast)
      document->blocks = collect(*ast);
    document->ast = std::move(ast);
  }
  return document;
}

// A paragraph appended to the finished blocks before they are parsed on their own. It comes back
// as the last top-level node only when the parser, too, has closed every block before it: inside a
// code fence or an HTML block it would be swallowed.
const char *const kProbe = "x";

bool isProbe(const MarkdownASTNode &node) {
  return node.type == NodeType::Paragraph && node.children.size() == 1 && node.children[0]->type == NodeType::Text &&
         node.children[0]->content == kProbe;
}

// Whether `markdown` can be parsed as two documents split at `offset`: a line that starts a block of
// its own begins there (or nothing does), after a blank line.
bool startsBlockAt(const std::string &markdown, size_t offset) {
  if (offset == 0 || offset >= markdown.size())
    return offset <= markdown.size();
  if (offset < 2 || markdown[offset - 1] != '\n')
    return false;
  size_t previous = markdown.rfind('\n', offset - 2);
  previous = previous == std::string::npos ? 0 : previous + 1;
  if (!isBlank(std::string_view(markdown).substr(previous, offset - 1 - previous)))
    return false;
  size_t lineEnd = markdown.find('\n', offset);
  return startsTopLevelBlock(
      std::string_view(markdown).substr(offset, lineEnd == std::string::npos ? lineEnd : lineEnd - offset));
}

} // namespace

size_t sharedLeadingBlocks(const ParsedDocument &a, const ParsedDocument &b) {
  if (!a.ast || !b.ast)
    return 0;
  const auto &first = a.ast->children;
  const auto &second = b.ast->children;
  size_t shared = 0;
  while (shared < first.size() && shared < second.size() && first[shared] == second[shared])
    shared++;
  return shared;
}

namespace {

bool holdsAny(const MarkdownASTNode &node, const std::unordered_set<const MarkdownASTNode *> &nodes) {
  if (nodes.count(&node) != 0)
    return true;
  for (const auto &child : node.children)
    if (holdsAny(*child, nodes))
      return true;
  return false;
}

} // namespace

size_t sharedLeadingBlocks(const ParsedDocument &a, const ParsedDocument &b,
                           const std::unordered_set<std::string> &aSlots,
                           const std::unordered_set<std::string> &bSlots) {
  size_t shared = sharedLeadingBlocks(a, b);
  if (shared == 0 || aSlots == bSlots)
    return shared;
  std::unordered_set<const MarkdownASTNode *> changed;
  for (const BlockSlot &slot : a.blocks.slots)
    if (aSlots.count(slot.id) != bSlots.count(slot.id))
      changed.insert(slot.node);
  if (changed.empty())
    return shared;
  const auto &blocks = a.ast->children;
  for (size_t i = 0; i < shared; i++)
    if (holdsAny(*blocks[i], changed))
      return i;
  return shared;
}

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
  // A streaming snapshot says where its finished blocks end; the stream's previous states have
  // parsed some of them already.
  size_t finishedBytes = 0;
  std::shared_ptr<const FinishedBlocks> finished;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    if (moveToFront(documents_, matches))
      return documents_.front().document;
    for (const SnapshotEntry &entry : snapshots_) {
      if (entry.options.flags == flags && entry.snapshot.markdown == markdown) {
        finishedBytes = entry.snapshot.finishedBytes;
        break;
      }
    }
    // The longest finished start this text shares: a shorter one would parse again, as new nodes,
    // blocks another entry already holds.
    for (const DocumentEntry &entry : documents_) {
      if (finishedBytes == 0)
        break;
      if (entry.finished && entry.isGFM == isGFM && entry.flags == flags && entry.finished->bytes <= finishedBytes &&
          entry.finished->bytes > (finished ? finished->bytes : 0) &&
          markdown.compare(0, entry.finished->bytes, entry.markdown, 0, entry.finished->bytes) == 0) {
        finished = entry.finished;
      }
    }
  }

  // Parsed outside the lock; if another thread parsed the same text meanwhile,
  // the first one stored wins so every caller shares one tree.
  parses_++;
  Parsed parsed = finishedBytes > 0 ? parseStreamed(markdown, finishedBytes, std::move(finished), flags, isGFM)
                                    : Parsed{parseWhole(markdown, flags, isGFM), nullptr};
  std::shared_ptr<const ParsedDocument> document = std::move(parsed.document);

  std::lock_guard<std::mutex> lock(mutex_);
  if (moveToFront(documents_, matches))
    return documents_.front().document;
  documents_.push_front({markdown, flags, isGFM, document, std::move(parsed.finished)});
  documentBytes_ += markdown.size() * kTreeBytesPerByte;
  evict(documents_, documentBytes_,
        [](const DocumentEntry &entry) { return entry.markdown.size() * kTreeBytesPerByte; });
  return document;
}

// `markdown` is a streaming snapshot whose first `finishedBytes` bytes are finished blocks, and
// `finished` what an earlier state of the stream parsed of them (null: nothing yet). Parses the
// finished blocks that are new and what follows them, each as a document of its own; whenever that
// could differ from parsing the whole text, parses the whole text.
DocumentStore::Parsed DocumentStore::parseStreamed(const std::string &markdown, size_t finishedBytes,
                                                   std::shared_ptr<const FinishedBlocks> finished,
                                                   const Md4cFlags &flags, bool isGFM) {
  const size_t known = finished ? finished->bytes : 0;
  // A reference definition changes links anywhere in the document. What is already finished has none.
  bool splittable = (!finished || finished->extendable) && startsBlockAt(markdown, known) &&
                    startsBlockAt(markdown, finishedBytes) &&
                    !mayDefineLinkReference(std::string_view(markdown).substr(known));

  if (splittable && finishedBytes > known) {
    std::string added = markdown.substr(known, finishedBytes - known);
    added.append(kProbe).append("\n");
    std::shared_ptr<MarkdownASTNode> root = MD4CParser().parse(added, flags, isGFM);
    std::shared_ptr<FinishedBlocks> next;
    if (root && !root->children.empty() && isProbe(*root->children.back())) {
      root->children.pop_back();
      next = std::make_shared<FinishedBlocks>(finished ? *finished : FinishedBlocks{});
      next->bytes = finishedBytes;
      for (auto &node : root->children) {
        next->collector.add(*node);
        next->nodes.push_back(std::move(node));
      }
    } else {
      // Kept under the text it happened for, so only this stream's later states find it.
      next = std::make_shared<FinishedBlocks>();
      next->bytes = finishedBytes;
      next->extendable = false;
      splittable = false;
    }
    finished = std::move(next);
  }

  if (!splittable || !finished)
    return {parseWhole(markdown, flags, isGFM), std::move(finished)};

  extendedParses_++;
  auto document = std::make_shared<ParsedDocument>();
  auto root = std::make_shared<MarkdownASTNode>(NodeType::Document);
  // Still linear in the finished blocks: their node pointers and collector are copied, not parsed.
  root->children = finished->nodes;
  BlockCollector collector = finished->collector;
  if (finishedBytes < markdown.size()) {
    if (std::shared_ptr<MarkdownASTNode> rest = MD4CParser().parse(markdown.substr(finishedBytes), flags, isGFM)) {
      for (auto &node : rest->children) {
        collector.add(*node);
        root->children.push_back(std::move(node));
      }
    }
  }
  document->blocks = std::move(collector.collected);
  document->ast = std::move(root);
  return {std::move(document), std::move(finished)};
}

void DocumentStore::clear() {
  std::lock_guard<std::mutex> lock(mutex_);
  snapshots_.clear();
  documents_.clear();
  snapshotBytes_ = 0;
  documentBytes_ = 0;
  snapshotsRun_ = 0;
  parses_ = 0;
  extendedParses_ = 0;
}

} // namespace Markdown
