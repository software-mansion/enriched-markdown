#include "EnrichedMarkdownParser.h"
#include "DocumentStore.hpp"
#include "ENRMMarkdownStreams.h"

#include <algorithm>

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
  core.strikethrough = flags.strikethrough;
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
  const Markdown::Md4cFlags coreFlags = toCoreFlags(flags);
  bool endsInsideOpenCodeFence = false;
  if (streaming.enabled) {
    Markdown::StreamingOptions options;
    options.blocks.tableMode = Markdown::streamingBlockModeFromName(streaming.tableMode);
    options.blocks.codeBlockMode = Markdown::streamingBlockModeFromName(streaming.codeBlockMode);
    options.blocks.mediaMode = Markdown::streamingBlockModeFromName(streaming.mediaMode);
    options.flags = coreFlags;
    auto snapshot = store.snapshot(markdown, options);
    markdown = std::move(snapshot.markdown);
    endsInsideOpenCodeFence = snapshot.endsInsideOpenCodeFence;
  }
  EnrichedMarkdownParserCollectedBlocks result;
  auto document = store.parse(markdown, coreFlags, isGFM);
  for (const auto &slot : document->blocks.slots) {
    result.slots.push_back(nativeSlot(slot, Markdown::isSlotComplete(document->blocks, slot, endsInsideOpenCodeFence)));
  }
  for (const auto &image : document->blocks.images) {
    result.images.push_back(
        {image.id, image.url, image.altText, image.title, Markdown::imagePlacementName(image.placement)});
  }
  for (const auto &link : document->blocks.links) {
    result.links.push_back({link.url, link.label, link.title});
  }
  return result;
}

EnrichedMarkdownParserCollectedBlocks
EnrichedMarkdownParser::collectStream(jsi::Runtime &rt, double streamId, double length,
                                      EnrichedMarkdownParserMd4cFlags flags, bool isGFM,
                                      EnrichedMarkdownParserStreamingOptions streaming) {
  std::string markdown =
      ENRMMarkdownStreams::shared().prefix(static_cast<int>(streamId), static_cast<size_t>(std::max(length, 0.0)));
  return collect(rt, std::move(markdown), flags, isGFM, streaming);
}

EnrichedMarkdownParser::~EnrichedMarkdownParser() {
  for (int id : streamIds_) {
    ENRMMarkdownStreams::shared().dispose(id);
  }
}

double EnrichedMarkdownParser::createStream(jsi::Runtime &, std::string text) {
  int id = ENRMMarkdownStreams::shared().create(std::move(text));
  streamIds_.insert(id);
  return id;
}

double EnrichedMarkdownParser::appendToStream(jsi::Runtime &, double streamId, std::string chunk) {
  return static_cast<double>(ENRMMarkdownStreams::shared().append(static_cast<int>(streamId), chunk));
}

void EnrichedMarkdownParser::disposeStream(jsi::Runtime &, double streamId) {
  streamIds_.erase(static_cast<int>(streamId));
  ENRMMarkdownStreams::shared().dispose(static_cast<int>(streamId));
}

} // namespace facebook::react
