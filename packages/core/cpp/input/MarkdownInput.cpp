#include "MarkdownInput.hpp"

namespace Markdown::Input {

// Skeleton: replaced by the real parser and serializer in the commits that follow.
ParseResult parse(std::u16string_view markdown) {
  ParseResult result;
  result.plainText = std::u16string(markdown);
  return result;
}

std::u16string serialize(std::u16string_view plainText, const std::vector<FormattingRange> &,
                         const std::vector<BlockRange> &) {
  return std::u16string(plainText);
}

void normalizeListMetadata(std::vector<BlockRange> &) {}

} // namespace Markdown::Input
