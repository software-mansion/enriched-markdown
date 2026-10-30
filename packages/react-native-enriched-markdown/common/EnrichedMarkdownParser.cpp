#include "EnrichedMarkdownParser.h"
#include "DocumentStore.hpp"

namespace facebook::react {

namespace {

Markdown::Md4cFlags toCoreFlags(const EnrichedMarkdownParserMd4cFlags &flags) {
  Markdown::Md4cFlags core;
  core.underline = flags.underline;
  // Android builds can leave math out (CMakeLists.txt); the host parses without it then.
  // TODO: one rule for both platforms: parse without math whenever it is compiled
  // out, keyed on ENRICHED_MARKDOWN_MATH (iOS already defines it) in collect and
  // both hosts. iOS parses math today even when RaTeX is out and drops the `$`.
#if ENRICHED_MARKDOWN_MATH_DISABLED
  core.latexMath = false;
#else
  core.latexMath = flags.latexMath;
#endif
  core.superscript = flags.superscript;
  core.subscript = flags.subscript;
  core.highlight = flags.highlight;
  core.hardSoftBreaks = flags.hardSoftBreaks;
  core.preserveBlankLines = flags.preserveBlankLines;
  core.admonitions = flags.admonitions;
  return core;
}

} // namespace

EnrichedMarkdownParser::EnrichedMarkdownParser(std::shared_ptr<CallInvoker> jsInvoker)
    : NativeEnrichedMarkdownParserCxxSpec(std::move(jsInvoker)) {}

EnrichedMarkdownParserCollectedBlocks
EnrichedMarkdownParser::collect(jsi::Runtime &, std::string markdown, EnrichedMarkdownParserMd4cFlags flags, bool isGFM,
                                EnrichedMarkdownParserStreamingOptions streaming) {
  auto &store = Markdown::DocumentStore::shared();
  if (streaming.enabled) {
    Markdown::StreamingFilterOptions options;
    options.tableMode = Markdown::streamingBlockModeFromName(streaming.tableMode);
    options.codeBlockMode = Markdown::streamingBlockModeFromName(streaming.codeBlockMode);
    options.mediaMode = Markdown::streamingBlockModeFromName(streaming.mediaMode);
    markdown = store.filter(markdown, options).markdown;
  }
  EnrichedMarkdownParserCollectedBlocks result;
  auto document = store.parse(markdown, toCoreFlags(flags), isGFM);
  for (const auto &slot : document->blocks.slots) {
    result.slots.push_back({slot.id, Markdown::blockSlotKindName(slot.kind), slot.url, slot.altText, slot.title,
                            Markdown::blockSlotPlacementName(slot.placement), slot.occurrenceId});
  }
  for (const auto &image : document->blocks.images) {
    result.images.push_back(
        {image.id, image.url, image.altText, image.title, Markdown::imagePlacementName(image.placement)});
  }
  return result;
}

} // namespace facebook::react
