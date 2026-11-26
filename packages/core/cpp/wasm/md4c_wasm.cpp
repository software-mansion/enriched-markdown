#include "../input/MarkdownInput.hpp"
#include "../parser/MD4CParser.hpp"
#include "ASTSerializer.hpp"
#include <cstdint>
#include <string>
#include <vector>

// Static buffer for the JSON result.
// Safe for single-threaded WASM execution — the caller must consume (copy)
// the returned string before calling parseMarkdown again.
static std::string g_resultBuffer;

// The input's markdown import and export (Markdown::Input). Everything crosses
// the boundary as plain memory in the wasm heap, no JSON: text and link URLs
// as UTF-16 code units, ranges as int32 records. Each call returns a pointer to
// a header of kHeaderInts int32 values describing where its result lives; the
// result stays valid until the next parseInput or serializeInput call, and the
// caller copies it out before then.
//
// Result header (int32 each):
//   0 text pointer (char16_t*)      1 text length in UTF-16 units
//   2 formatting records pointer    3 formatting record count
//   4 block records pointer         5 block record count
//   6 link URL pool pointer         7 link URL pool length in UTF-16 units
// Formatting record (kFormattingInts): type, start, end, url offset, url length
// (offset and length index the URL pool). Block record (kBlockInts): type,
// start, end, level, ordinal. `type` is the numeric value of the C++ enum.
namespace {

constexpr int kHeaderInts = 8;
constexpr int kFormattingInts = 5;
constexpr int kBlockInts = 5;

struct InputResult {
  int32_t header[kHeaderInts] = {0};
  std::u16string text;
  std::vector<int32_t> formatting;
  std::vector<int32_t> blocks;
  std::u16string urls;
};

InputResult g_inputResult;

int32_t pointerValue(const void *pointer) {
  return static_cast<int32_t>(reinterpret_cast<uintptr_t>(pointer));
}

void publish(InputResult &result) {
  int32_t *header = result.header;
  header[0] = pointerValue(result.text.data());
  header[1] = static_cast<int32_t>(result.text.size());
  header[2] = pointerValue(result.formatting.data());
  header[3] = static_cast<int32_t>(result.formatting.size() / kFormattingInts);
  header[4] = pointerValue(result.blocks.data());
  header[5] = static_cast<int32_t>(result.blocks.size() / kBlockInts);
  header[6] = pointerValue(result.urls.data());
  header[7] = static_cast<int32_t>(result.urls.size());
}

} // namespace

extern "C" {

/**
 * Markdown to plain text and ranges (Markdown::Input::parse).
 *
 * @param markdown UTF-16 markdown, `length` code units, not null-terminated.
 * @return         Pointer to the result header, valid until the next call.
 */
const int32_t *parseInput(const char16_t *markdown, int length) {
  InputResult &result = g_inputResult;
  result = InputResult();
  const Markdown::Input::ParseResult parsed =
      Markdown::Input::parse(std::u16string_view(markdown, static_cast<size_t>(length < 0 ? 0 : length)));
  result.text = parsed.plainText;
  for (const auto &range : parsed.formattingRanges) {
    result.formatting.push_back(static_cast<int32_t>(range.type));
    result.formatting.push_back(static_cast<int32_t>(range.start));
    result.formatting.push_back(static_cast<int32_t>(range.end));
    result.formatting.push_back(static_cast<int32_t>(result.urls.size()));
    result.formatting.push_back(static_cast<int32_t>(range.url.size()));
    result.urls += range.url;
  }
  for (const auto &block : parsed.blockRanges) {
    result.blocks.push_back(static_cast<int32_t>(block.type));
    result.blocks.push_back(static_cast<int32_t>(block.start));
    result.blocks.push_back(static_cast<int32_t>(block.end));
    result.blocks.push_back(static_cast<int32_t>(block.level));
    result.blocks.push_back(static_cast<int32_t>(block.ordinal));
  }
  publish(result);
  return result.header;
}

/**
 * Plain text and ranges to markdown (Markdown::Input::serialize). The ranges
 * use the record layouts above; the URL pool holds the links' destinations.
 *
 * @return Pointer to the result header (text only), valid until the next call.
 */
const int32_t *serializeInput(const char16_t *text, int textLength, const int32_t *formatting, int formattingCount,
                              const char16_t *urls, int urlsLength, const int32_t *blocks, int blockCount) {
  std::vector<Markdown::Input::FormattingRange> formattingRanges;
  formattingRanges.reserve(static_cast<size_t>(formattingCount));
  for (int i = 0; i < formattingCount; i++) {
    const int32_t *record = formatting + i * kFormattingInts;
    Markdown::Input::FormattingRange range;
    range.type = static_cast<Markdown::Input::StyleType>(record[0]);
    range.start = static_cast<uint32_t>(record[1]);
    range.end = static_cast<uint32_t>(record[2]);
    if (record[4] > 0 && record[3] >= 0 && record[3] + record[4] <= urlsLength) {
      range.url.assign(urls + record[3], static_cast<size_t>(record[4]));
    }
    formattingRanges.push_back(std::move(range));
  }
  std::vector<Markdown::Input::BlockRange> blockRanges;
  blockRanges.reserve(static_cast<size_t>(blockCount));
  for (int i = 0; i < blockCount; i++) {
    const int32_t *record = blocks + i * kBlockInts;
    Markdown::Input::BlockRange range;
    range.type = static_cast<Markdown::Input::BlockType>(record[0]);
    range.start = static_cast<uint32_t>(record[1]);
    range.end = static_cast<uint32_t>(record[2]);
    range.level = static_cast<uint8_t>(record[3]);
    range.ordinal = static_cast<uint32_t>(record[4]);
    blockRanges.push_back(range);
  }

  InputResult &result = g_inputResult;
  result = InputResult();
  result.text = Markdown::Input::serialize(
      std::u16string_view(text, static_cast<size_t>(textLength < 0 ? 0 : textLength)), formattingRanges, blockRanges);
  publish(result);
  return result.header;
}

/**
 * Parse a markdown string and return its AST as a JSON string.
 *
 * @param markdown   Null-terminated UTF-8 markdown input.
 * @param underline  1 → enable __ underline extension; 0 → __ means emphasis.
 * @param latexMath  1 → enable $…$ / $$…$$ LaTeX math spans; 0 → disable.
 * @param superscript 1 → enable ^superscript^ spans; 0 → disable.
 * @param subscript  1 → enable ~subscript~ spans; 0 → disable.
 * @param highlight  1 → enable ==highlight== spans; 0 → disable.
 * @param hardSoftBreaks 1 → treat soft breaks as hard breaks; 0 → collapse to space.
 * @param preserveBlankLines 1 → report runs of blank lines as BlankLine nodes; 0 → collapse them.
 * @param admonitions 1 → enable GitHub-style admonitions/alerts; 0 → disable.
 * @param permissiveAutolinks 1 → autolink bare URLs/e-mails; 0 → explicit links only.
 * @return           Null-terminated UTF-8 JSON string, valid until the next call.
 */
const char *parseMarkdown(const char *markdown, int underline, int latexMath, int superscript, int subscript,
                          int highlight, int hardSoftBreaks, int preserveBlankLines, int admonitions,
                          int permissiveAutolinks) {
  if (!markdown) {
    g_resultBuffer = "{\"type\":\"Document\"}";
    return g_resultBuffer.c_str();
  }

  Markdown::Md4cFlags flags;
  flags.underline = (underline != 0);
  flags.latexMath = (latexMath != 0);
  flags.superscript = (superscript != 0);
  flags.subscript = (subscript != 0);
  flags.highlight = (highlight != 0);
  flags.hardSoftBreaks = (hardSoftBreaks != 0);
  flags.preserveBlankLines = (preserveBlankLines != 0);
  flags.admonitions = (admonitions != 0);
  flags.permissiveAutolinks = (permissiveAutolinks != 0);

  Markdown::MD4CParser parser;
  auto root = parser.parse(std::string(markdown), flags);
  g_resultBuffer = Markdown::ASTSerializer::serialize(*root);
  return g_resultBuffer.c_str();
}

} // extern "C"
