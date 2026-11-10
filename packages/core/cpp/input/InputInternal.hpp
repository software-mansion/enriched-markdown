#pragma once

#include "MarkdownInput.hpp"
#include <cstddef>
#include <cstdint>
#include <string_view>
#include <vector>

// Pieces of the module the tests reach into. Not part of the host-facing API.
namespace Markdown::Input {

// markdownEscape.ts: the indices in `text` to put a backslash in front of,
// ascending. A position does not depend on the delimiters written around it.
std::vector<uint32_t> markdownEscapePositions(std::u16string_view text);

} // namespace Markdown::Input
