#pragma once

#include <string>

// Display names for code block fence languages, shared by every platform and
// both markdown flavors so a fence like ```python is labeled identically
// everywhere. Unlike the highlighting seam this is always compiled; it does
// not depend on ENRICHED_MARKDOWN_CODE_HIGHLIGHT.

namespace Markdown {

// Maps a fence info string (for example "python", "js") to a human readable
// display name ("Python", "JavaScript"). Unknown languages fall back to the
// lowercased input with the first ASCII letter capitalized. Empty input
// returns an empty string.
std::string displayNameForLanguage(const std::string& language);

} // namespace Markdown
