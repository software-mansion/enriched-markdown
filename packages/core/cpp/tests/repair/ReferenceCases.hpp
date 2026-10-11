// Shape of the test data table in ReferenceCases.cpp.
#pragma once

#include <cstddef>
#include <cstdint>
#include <string_view>

#include "MarkdownRepair.hpp"

namespace ReferenceCases {

struct Case {
  std::string_view input;
  Markdown::RepairOptions options;
  std::string_view expected;
};

enum class Helper { IsWordChar, IsWithinCodeBlock, IsWithinMathBlock, IsWithinLinkOrImageUrl };

struct HelperCall {
  Helper fn;
  std::string_view text;
  uint32_t argument;  // code point for IsWordChar, byte position otherwise
  bool expected;
};

extern const char *const kReferenceVersion;
extern const Case kCases[];
extern const size_t kCaseCount;
extern const HelperCall kHelperCalls[];
extern const size_t kHelperCallCount;

}  // namespace ReferenceCases
