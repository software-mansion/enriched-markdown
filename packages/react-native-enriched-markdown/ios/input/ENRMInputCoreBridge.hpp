#pragma once

#import "ENRMBlockRange.h"
#import "ENRMFormattingRange.h"
#include "MarkdownInput.hpp"
#import <Foundation/Foundation.h>
#include <string>
#include <vector>

// Conversions between the editor's Objective-C model and the plain data the
// shared input core (cpp/input) works on. Offsets are UTF-16 on both sides, so
// ranges pass through untouched. Kept out of the pod's umbrella header (.hpp).
namespace ENRMInputCoreBridge {

inline std::u16string toU16(NSString *string) {
  std::u16string result(string.length, u'\0');
  if (string.length > 0) {
    [string getCharacters:reinterpret_cast<unichar *>(result.data()) range:NSMakeRange(0, string.length)];
  }
  return result;
}

inline NSString *toNSString(const std::u16string &string) {
  return [NSString stringWithCharacters:reinterpret_cast<const unichar *>(string.data()) length:string.size()];
}

inline std::vector<Markdown::Input::FormattingRange> toCore(NSArray<ENRMFormattingRange *> *ranges) {
  std::vector<Markdown::Input::FormattingRange> result;
  result.reserve(ranges.count);
  for (ENRMFormattingRange *range in ranges) {
    if (range.type < ENRMInputStyleTypeStrong || range.type > ENRMInputStyleTypeSpoiler) {
      continue;
    }
    Markdown::Input::FormattingRange converted;
    converted.type = static_cast<Markdown::Input::StyleType>(range.type);
    converted.start = static_cast<uint32_t>(range.range.location);
    converted.end = static_cast<uint32_t>(NSMaxRange(range.range));
    if (range.url != nil) {
      converted.url = toU16(range.url);
    }
    result.push_back(std::move(converted));
  }
  return result;
}

inline std::vector<Markdown::Input::BlockRange> toCore(NSArray<ENRMBlockRange *> *blocks) {
  std::vector<Markdown::Input::BlockRange> result;
  result.reserve(blocks.count);
  for (ENRMBlockRange *block in blocks) {
    if (block.type < ENRMInputBlockTypeParagraph || block.type > ENRMInputBlockTypeOrderedListItem) {
      continue;
    }
    Markdown::Input::BlockRange converted;
    converted.type = static_cast<Markdown::Input::BlockType>(block.type);
    converted.start = static_cast<uint32_t>(block.range.location);
    converted.end = static_cast<uint32_t>(NSMaxRange(block.range));
    converted.level = static_cast<uint8_t>(MAX(0, MIN(block.level, 255)));
    converted.ordinal = static_cast<uint32_t>(MAX(0, block.ordinal));
    result.push_back(converted);
  }
  return result;
}

} // namespace ENRMInputCoreBridge
