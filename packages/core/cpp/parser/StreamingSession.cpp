#include "StreamingSession.hpp"
#include "MarkdownRepair.hpp"
#include <string_view>

namespace Markdown {

RepairOptions streamingRepairOptions(const Md4cFlags &flags) {
  RepairOptions options;
  options.linkMode = LinkMode::TextOnly;
  options.withholdIncomplete = true;
  options.inlineMath = flags.latexMath;
  options.displayMath = flags.latexMath;
  options.withholdMath = flags.latexMath;
  options.superscript = flags.superscript;
  options.subscript = flags.subscript;
  options.highlight = flags.highlight;
  // Escapes every single `~` in the document, not only in the unfinished tail,
  // so a paragraph would change once it is finished. The parser's flags decide
  // what `~` means.
  options.singleTilde = false;
  return options;
}

StreamingSnapshot streamingSnapshot(const std::string &source, const StreamingOptions &options) {
  StreamingSnapshot snapshot;
  snapshot.finishedBytes = finishedBlocksEnd(source, options.flags.latexMath);
  StreamingFilterResult tail =
      renderableMarkdownForStreaming(source.substr(snapshot.finishedBytes), options.blocks, options.flags.latexMath);
  // Repair sees the text as it arrived: an added delimiter row stays only while repair leaves the
  // header above it alone. Closing a `**` there would turn the table back into a paragraph, so the
  // header is held back then, as it was before it could show early.
  std::string added = tail.markdown.substr(tail.markdown.size() - tail.addedBytes);
  tail.markdown.resize(tail.markdown.size() - tail.addedBytes);
  std::string arrived = tail.markdown;
  repairInlineMarkdownInPlace(tail.markdown, streamingRepairOptions(options.flags));
  if (!added.empty()) {
    if (tail.markdown == arrived) {
      tail.markdown.append(added);
    } else {
      size_t header = arrived.size() >= 2 ? arrived.rfind('\n', arrived.size() - 2) : std::string::npos;
      tail.markdown = arrived.substr(0, header == std::string::npos ? 0 : header + 1);
      repairInlineMarkdownInPlace(tail.markdown, streamingRepairOptions(options.flags));
    }
  }
  snapshot.endsInsideOpenCodeFence = tail.endsInsideOpenCodeFence;
  // Finished too when the next character would begin a block of its own: the source ends with a
  // blank line outside fences, `$$` math and HTML blocks (counted from the finished bytes on).
  bool blank = tail.markdown.find_first_not_of(" \t\r\n") == std::string::npos;
  bool endsBlock = false;
  if (!blank && !tail.endsInsideOpenCodeFence && source.size() >= 2 && source.back() == '\n') {
    std::string next = source.substr(snapshot.finishedBytes);
    next.push_back('x');
    endsBlock = finishedBlocksEnd(next, options.flags.latexMath) == next.size() - 1;
  }
  snapshot.showsOnlyFinishedBlocks = (snapshot.finishedBytes > 0 && blank) || endsBlock;
  snapshot.markdown.reserve(snapshot.finishedBytes + tail.markdown.size());
  snapshot.markdown.append(source, 0, snapshot.finishedBytes).append(tail.markdown);
  return snapshot;
}

FinishedListItems streamingListItems(const std::string &source, const StreamingSnapshot &snapshot,
                                     const StreamingOptions &options) {
  size_t finished = snapshot.finishedBytes;
  std::string_view unfinished = std::string_view(source).substr(finished);
  FinishedListItems items = finishedListItems(unfinished, options.flags.latexMath);
  if (items.end == 0 || snapshot.markdown.compare(finished, items.end, unfinished, 0, items.end) != 0)
    return {finished, finished};
  return {finished + items.end, finished + items.lastItem};
}

} // namespace Markdown
