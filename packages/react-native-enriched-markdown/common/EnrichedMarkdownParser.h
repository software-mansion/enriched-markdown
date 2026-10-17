#pragma once

// Android exposes generated/jni/react/renderer/components (the spec folder by
// name, so no other generated header is reachable bare); iOS generates the JSI
// header flat under ios/generated/ReactCodegen.
#if __has_include("EnrichedMarkdownTextSpec/EnrichedMarkdownTextSpecJSI.h")
#include "EnrichedMarkdownTextSpec/EnrichedMarkdownTextSpecJSI.h"
#else
#include "EnrichedMarkdownTextSpecJSI.h"
#endif
#include <memory>
#include <string>
#include <vector>

namespace facebook::react {

using EnrichedMarkdownParserBlockSlot =
    NativeEnrichedMarkdownParserNativeBlockSlot<std::string, std::string, std::string, std::string, std::string,
                                                std::string>;
template <>
struct Bridging<EnrichedMarkdownParserBlockSlot>
    : NativeEnrichedMarkdownParserNativeBlockSlotBridging<EnrichedMarkdownParserBlockSlot> {};

using EnrichedMarkdownParserImageOccurrence =
    NativeEnrichedMarkdownParserNativeImageOccurrence<std::string, std::string, std::string, std::string, std::string>;
template <>
struct Bridging<EnrichedMarkdownParserImageOccurrence>
    : NativeEnrichedMarkdownParserNativeImageOccurrenceBridging<EnrichedMarkdownParserImageOccurrence> {};

using EnrichedMarkdownParserMd4cFlags =
    NativeEnrichedMarkdownParserNativeMd4cFlags<bool, bool, bool, bool, bool, bool, bool, bool>;
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
                                                      std::vector<EnrichedMarkdownParserImageOccurrence>>;
template <>
struct Bridging<EnrichedMarkdownParserCollectedBlocks>
    : NativeEnrichedMarkdownParserNativeCollectedBlocksBridging<EnrichedMarkdownParserCollectedBlocks> {};

/**
 * Pure C++ TurboModule exposing the core's block collector to JS synchronously.
 * It runs the same streaming filter and parses with the same md4c core the
 * native hosts render with, so the ids it returns are the ids the hosts stamp
 * on their AST (see BlockSlots.hpp). Shared by iOS (EnrichedMarkdownParserProvider)
 * and Android (parser-module/CMakeLists.txt).
 */
class EnrichedMarkdownParser : public NativeEnrichedMarkdownParserCxxSpec<EnrichedMarkdownParser> {
public:
  explicit EnrichedMarkdownParser(std::shared_ptr<CallInvoker> jsInvoker);

  EnrichedMarkdownParserCollectedBlocks collect(jsi::Runtime &rt, std::string markdown,
                                                EnrichedMarkdownParserMd4cFlags flags, bool isGFM,
                                                EnrichedMarkdownParserStreamingOptions streaming);
};

} // namespace facebook::react
