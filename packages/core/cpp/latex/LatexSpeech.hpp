#pragma once

#include <string>
#include <string_view>

// English reading of a LaTeX formula for screen readers ("x squared over 2"
// rather than "x caret 2 slash 2"), shared by every platform so VoiceOver and
// TalkBack speak a formula identically.

namespace Markdown {

std::string spokenLatex(std::string_view latex);

} // namespace Markdown
