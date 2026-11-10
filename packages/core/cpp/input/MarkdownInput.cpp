#include "MarkdownInput.hpp"

namespace Markdown::Input {

// Skeleton: replaced by the real serializer in a later commit.
std::u16string serialize(std::u16string_view plainText, const std::vector<FormattingRange> &,
                         const std::vector<BlockRange> &) {
  return std::u16string(plainText);
}

} // namespace Markdown::Input
