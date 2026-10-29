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

// The spec's slot is one flat struct for every kind, with "" for the fields a
// kind lacks.
EnrichedMarkdownParserBlockSlot nativeSlot(const Markdown::BlockSlot &slot, bool isComplete) {
  EnrichedMarkdownParserBlockSlot out{};
  out.id = slot.id;
  out.kind = Markdown::blockSlotKindName(slot.kind());
  out.placement = Markdown::blockSlotPlacementName(slot.placement);
  out.isComplete = isComplete;
  if (const auto *image = std::get_if<Markdown::ImageSlotFields>(&slot.fields)) {
    out.url = image->url;
    out.altText = image->altText;
    out.title = image->title;
    out.occurrenceId = image->occurrenceId;
  } else if (const auto *video = std::get_if<Markdown::VideoSlotFields>(&slot.fields)) {
    out.url = video->url;
  } else if (const auto *link = std::get_if<Markdown::LinkSlotFields>(&slot.fields)) {
    out.url = link->url;
    out.altText = link->label;
    out.title = link->title;
  } else if (const auto *code = std::get_if<Markdown::CodeSlotFields>(&slot.fields)) {
    out.language = code->language;
    out.code = code->code;
  }
  return out;
}

} // namespace

EnrichedMarkdownParser::EnrichedMarkdownParser(std::shared_ptr<CallInvoker> jsInvoker)
    : NativeEnrichedMarkdownParserCxxSpec(std::move(jsInvoker)) {}

EnrichedMarkdownParserCollectedBlocks
EnrichedMarkdownParser::collect(jsi::Runtime &, std::string markdown, EnrichedMarkdownParserMd4cFlags flags, bool isGFM,
                                EnrichedMarkdownParserStreamingOptions streaming) {
  auto &store = Markdown::DocumentStore::shared();
  bool endsInsideOpenCodeFence = false;
  if (streaming.enabled) {
    Markdown::StreamingFilterOptions options;
    options.tableMode = Markdown::streamingBlockModeFromName(streaming.tableMode);
    options.codeBlockMode = Markdown::streamingBlockModeFromName(streaming.codeBlockMode);
    options.mediaMode = Markdown::streamingBlockModeFromName(streaming.mediaMode);
    auto filtered = store.filter(markdown, options);
    markdown = std::move(filtered.markdown);
    endsInsideOpenCodeFence = filtered.endsInsideOpenCodeFence;
  }
  EnrichedMarkdownParserCollectedBlocks result;
  auto document = store.parse(markdown, toCoreFlags(flags), isGFM);
  for (const auto &slot : document->blocks.slots) {
    result.slots.push_back(nativeSlot(slot, Markdown::isSlotComplete(document->blocks, slot, endsInsideOpenCodeFence)));
  }
  for (const auto &image : document->blocks.images) {
    result.images.push_back(
        {image.id, image.url, image.altText, image.title, Markdown::imagePlacementName(image.placement)});
  }
  return result;
}

} // namespace facebook::react
