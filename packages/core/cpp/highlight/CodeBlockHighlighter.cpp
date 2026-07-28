#include "CodeBlockHighlighter.hpp"

// Stub compiled when the syntax highlighting module is disabled. The real
// implementation defines the same symbol under ENRICHED_MARKDOWN_CODE_HIGHLIGHT,
// so exactly one definition exists in any build configuration.

#if !defined(ENRICHED_MARKDOWN_CODE_HIGHLIGHT)

namespace Markdown {

std::vector<HighlightToken> highlightCode(const std::string & /*code*/, const std::string & /*language*/) {
  return {};
}

} // namespace Markdown

#endif
