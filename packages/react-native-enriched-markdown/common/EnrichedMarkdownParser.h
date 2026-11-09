#pragma once

// Android exposes the codegen jni/react/renderer/components folder (the spec
// folder by name, so no other generated header is reachable bare); iOS has the
// JSI header flat at the root of the app's ReactCodegen pod.
#if __has_include("EnrichedMarkdownTextSpec/EnrichedMarkdownTextSpecJSI.h")
#include "EnrichedMarkdownTextSpec/EnrichedMarkdownTextSpecJSI.h"
#else
#include "EnrichedMarkdownTextSpecJSI.h"
#endif
#include <memory>
#include <unordered_set>
#include <string>
#include <vector>

namespace facebook::react {

using EnrichedMarkdownParserBlockSlot =
    NativeEnrichedMarkdownParserNativeBlockSlot<std::string, std::string, std::string, std::string, std::string,
                                                std::string, std::string, std::string, std::string, bool>;
template <>
struct Bridging<EnrichedMarkdownParserBlockSlot>
    : NativeEnrichedMarkdownParserNativeBlockSlotBridging<EnrichedMarkdownParserBlockSlot> {};

using EnrichedMarkdownParserImageOccurrence =
    NativeEnrichedMarkdownParserNativeImageOccurrence<std::string, std::string, std::string, std::string, std::string>;
template <>
struct Bridging<EnrichedMarkdownParserImageOccurrence>
    : NativeEnrichedMarkdownParserNativeImageOccurrenceBridging<EnrichedMarkdownParserImageOccurrence> {};

using EnrichedMarkdownParserLinkOccurrence =
    NativeEnrichedMarkdownParserNativeLinkOccurrence<std::string, std::string, std::string>;
template <>
struct Bridging<EnrichedMarkdownParserLinkOccurrence>
    : NativeEnrichedMarkdownParserNativeLinkOccurrenceBridging<EnrichedMarkdownParserLinkOccurrence> {};

using EnrichedMarkdownParserMd4cFlags =
    NativeEnrichedMarkdownParserNativeMd4cFlags<bool, bool, bool, bool, bool, bool, bool, bool, bool>;
template <>
struct Bridging<EnrichedMarkdownParserMd4cFlags>
    : NativeEnrichedMarkdownParserNativeMd4cFlagsBridging<EnrichedMarkdownParserMd4cFlags> {};

using EnrichedMarkdownParserStreamingOptions =
    NativeEnrichedMarkdownParserNativeStreamingOptions<bool, std::string, std::string, std::string>;
template <>
struct Bridging<EnrichedMarkdownParserStreamingOptions>
    : NativeEnrichedMarkdownParserNativeStreamingOptionsBridging<EnrichedMarkdownParserStreamingOptions> {};

using EnrichedMarkdownParserCollectedBlocks =
    NativeEnrichedMarkdownParserNativeCollectedBlocks<std::vector<EnrichedMarkdownParserBlockSlot>,
                                                      std::vector<EnrichedMarkdownParserImageOccurrence>,
                                                      std::vector<EnrichedMarkdownParserLinkOccurrence>>;
template <>
struct Bridging<EnrichedMarkdownParserCollectedBlocks>
    : NativeEnrichedMarkdownParserNativeCollectedBlocksBridging<EnrichedMarkdownParserCollectedBlocks> {};

/**
 * Pure C++ TurboModule exposing the core's block collector to JS synchronously.
 * It filters and parses through the DocumentStore the native hosts use, so the
 * tick's measurement and render reuse its document and see the same ids. Shared
 * by iOS (EnrichedMarkdownParserProvider) and Android (parser-module/CMakeLists.txt).
 * It also keeps the text of JS's markdown streams (ENRMMarkdownStreams).
 */
class EnrichedMarkdownParser : public NativeEnrichedMarkdownParserCxxSpec<EnrichedMarkdownParser> {
public:
  explicit EnrichedMarkdownParser(std::shared_ptr<CallInvoker> jsInvoker);
  ~EnrichedMarkdownParser() override;

  EnrichedMarkdownParserCollectedBlocks collect(jsi::Runtime &rt, std::string markdown,
                                                EnrichedMarkdownParserMd4cFlags flags, bool isGFM,
                                                EnrichedMarkdownParserStreamingOptions streaming);
  EnrichedMarkdownParserCollectedBlocks collectStream(jsi::Runtime &rt, double streamId, double length,
                                                      EnrichedMarkdownParserMd4cFlags flags, bool isGFM,
                                                      EnrichedMarkdownParserStreamingOptions streaming);
  double createStream(jsi::Runtime &rt, std::string text);
  double appendToStream(jsi::Runtime &rt, double streamId, std::string chunk);
  void disposeStream(jsi::Runtime &rt, double streamId);

private:
  // This runtime's streams: a JS reload drops them without dispose().
  std::unordered_set<int> streamIds_;
};

} // namespace facebook::react
