#include "InputInternal.hpp"
#include <algorithm>
#include <array>
#include <optional>
#include <unordered_map>

// normalizeImport.ts, plus the list metadata pass of BlockStore.
namespace Markdown::Input {

std::vector<size_t> lineStartsOf(std::u16string_view text) {
  std::vector<size_t> lineStarts{0};
  for (size_t lineBreak = text.find(u'\n'); lineBreak != std::u16string_view::npos;
       lineBreak = text.find(u'\n', lineBreak + 1)) {
    lineStarts.push_back(lineBreak + 1);
  }
  return lineStarts;
}

std::vector<FormattingRange> normalizeFormattingRanges(std::vector<FormattingRange> ranges) {
  std::stable_sort(ranges.begin(), ranges.end(),
                   [](const FormattingRange &a, const FormattingRange &b) { return a.start < b.start; });
  std::vector<FormattingRange> merged;
  merged.reserve(ranges.size());
  // The last merged range of each type, and of each url for links.
  std::array<std::optional<size_t>, 6> openByType;
  std::unordered_map<std::u16string, size_t> openLinks;
  for (FormattingRange &range : ranges) {
    if (range.end <= range.start) {
      continue;
    }
    const bool isLink = range.type == StyleType::Link;
    const size_t *open = nullptr;
    if (isLink) {
      const auto it = openLinks.find(range.url);
      open = it == openLinks.end() ? nullptr : &it->second;
    } else if (openByType[static_cast<size_t>(range.type)].has_value()) {
      open = &*openByType[static_cast<size_t>(range.type)];
    }
    if (open != nullptr) {
      FormattingRange &last = merged[*open];
      if (range.start <= last.end) {
        last.end = std::max(last.end, range.end);
        continue;
      }
    }
    if (isLink) {
      openLinks[range.url] = merged.size();
    } else {
      openByType[static_cast<size_t>(range.type)] = merged.size();
    }
    merged.push_back(std::move(range));
  }
  return merged;
}

namespace {

bool isListItem(BlockType type) {
  return type == BlockType::UnorderedListItem || type == BlockType::OrderedListItem;
}

bool isHeading(BlockType type) {
  return type >= BlockType::H1 && type <= BlockType::H6;
}

// When two blocks claim one line, the one kept. A list item is the outer
// structure ("- # foo" is an item holding a heading), and losing it would break
// the list's numbering and nesting around it; the line's text stays either way.
int blockPriority(BlockType type) {
  if (isListItem(type)) {
    return 2;
  }
  return isHeading(type) ? 1 : 0;
}

} // namespace

std::vector<BlockRange> normalizeBlockRanges(std::u16string_view text, const std::vector<BlockRange> &blocks) {
  if (blocks.empty()) {
    return {};
  }
  const std::vector<size_t> lineStarts = lineStartsOf(text);
  const size_t lineCount = lineStarts.size();
  const auto lineEnd = [&](size_t line) { return lineEndOf(text, lineStarts, line); };

  // Indexed by line. Blocks arrive nearly sorted (a nested item is emitted
  // before its parent), so the line of each start is found walking from the
  // previous one, with a binary search only to go back.
  std::vector<BlockRange> byLine(lineCount);
  std::vector<char> filled(lineCount, 0);
  size_t cursor = 0;
  const auto lineAt = [&](size_t position) {
    if (position < lineStarts[cursor]) {
      // Leftmost line whose end reaches the position.
      size_t low = 0;
      size_t high = lineCount;
      while (low < high) {
        const size_t mid = low + (high - low) / 2;
        if (lineEnd(mid) < position) {
          low = mid + 1;
        } else {
          high = mid;
        }
      }
      cursor = low;
    }
    while (cursor + 1 < lineCount && lineEnd(cursor) < position) {
      cursor++;
    }
    return cursor;
  };
  for (const BlockRange &block : blocks) {
    const size_t first = lineAt(block.start);
    size_t last = first;
    // `lineEnd(last) < block.end - 1`, without going below zero.
    while (last + 1 < lineCount && lineEnd(last) + 1 < block.end) {
      last++;
    }
    for (size_t line = first; line <= last; line++) {
      if (filled[line] && blockPriority(byLine[line].type) >= blockPriority(block.type)) {
        continue;
      }
      byLine[line] = block;
      byLine[line].start = static_cast<uint32_t>(lineStarts[line]);
      byLine[line].end = static_cast<uint32_t>(lineEnd(line));
      filled[line] = 1;
    }
  }
  std::vector<BlockRange> result;
  for (size_t line = 0; line < lineCount; line++) {
    if (filled[line]) {
      result.push_back(byLine[line]);
    }
  }
  return result;
}

void normalizeListMetadata(std::vector<BlockRange> &blockRanges) {
  constexpr size_t kDepths = kMaxListDepth + 1;
  int64_t prevEnd = -2;
  int prevDepth = -1;
  std::array<uint32_t, kDepths> counters{};
  std::array<std::optional<BlockType>, kDepths> counterTypes{};

  for (BlockRange &range : blockRanges) {
    if (!isListItem(range.type)) {
      prevDepth = -1;
      continue;
    }
    const bool adjacent = prevDepth >= 0 && static_cast<int64_t>(range.start) == prevEnd + 1;
    if (!adjacent) {
      counters.fill(0);
      counterTypes.fill(std::nullopt);
    }
    const int maxDepth = std::min(adjacent ? prevDepth + 1 : 0, static_cast<int>(kMaxListDepth));
    if (range.level > maxDepth) {
      range.level = static_cast<uint8_t>(maxDepth);
    }
    const size_t depth = range.level;
    for (size_t i = depth + 1; i < kDepths; i++) {
      counters[i] = 0;
      counterTypes[i] = std::nullopt;
    }
    if (counterTypes[depth] != range.type) {
      counters[depth] = 0;
      counterTypes[depth] = range.type;
    }
    range.ordinal = ++counters[depth];
    prevEnd = range.end;
    prevDepth = range.level;
  }
}

} // namespace Markdown::Input
