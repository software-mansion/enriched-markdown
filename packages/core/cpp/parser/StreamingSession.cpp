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
  snapshot.finishedBytes = finishedBlocksEnd(source);
  StreamingFilterResult tail = renderableMarkdownForStreaming(source.substr(snapshot.finishedBytes), options.blocks);
  repairInlineMarkdownInPlace(tail.markdown, streamingRepairOptions(options.flags));
  snapshot.endsInsideOpenCodeFence = tail.endsInsideOpenCodeFence;
  snapshot.markdown.reserve(snapshot.finishedBytes + tail.markdown.size());
  snapshot.markdown.append(source, 0, snapshot.finishedBytes).append(tail.markdown);
  return snapshot;
}

} // namespace Markdown
