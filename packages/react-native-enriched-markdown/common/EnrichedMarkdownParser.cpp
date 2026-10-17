#include "EnrichedMarkdownParser.h"
#include "BlockSlots.hpp"
#include "MD4CParser.hpp"
#include "StreamingFilter.hpp"

namespace facebook::react {

namespace {

Markdown::Md4cFlags toCoreFlags(const EnrichedMarkdownParserMd4cFlags &flags) {
  Markdown::Md4cFlags core;
  core.underline = flags.underline;
  core.latexMath = flags.latexMath;
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
  EnrichedMarkdownParserCollectedBlocks result;
  if (streaming.enabled) {
    Markdown::StreamingFilterOptions options;
    options.tableMode = Markdown::streamingBlockModeFromName(streaming.tableMode);
    options.codeBlockMode = Markdown::streamingBlockModeFromName(streaming.codeBlockMode);
    options.mediaMode = Markdown::streamingBlockModeFromName(streaming.mediaMode);
    markdown = Markdown::renderableMarkdownForStreaming(markdown, options).markdown;
  }
  if (markdown.empty()) {
    return result;
  }
  Markdown::MD4CParser parser;
  auto ast = parser.parse(markdown, toCoreFlags(flags), isGFM);
  if (!ast) {
    return result;
  }
  auto collected = Markdown::collect(*ast);
  for (auto &slot : collected.slots) {
    result.slots.push_back({std::move(slot.id), Markdown::blockSlotKindName(slot.kind), std::move(slot.url),
                            std::move(slot.altText), std::move(slot.title),
                            Markdown::blockSlotPlacementName(slot.placement)});
  }
  for (auto &image : collected.images) {
    result.images.push_back({std::move(image.id), std::move(image.url), std::move(image.altText),
                             std::move(image.title), Markdown::imagePlacementName(image.placement)});
  }
  return result;
}

} // namespace facebook::react
