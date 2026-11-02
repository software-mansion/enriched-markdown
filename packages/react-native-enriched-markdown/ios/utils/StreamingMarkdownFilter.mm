#import "StreamingMarkdownFilter.h"
#include "DocumentStore.hpp"
#import "ENRMUTF8.h"
#include <string>

// Thin bridge to the core's filter, the single owner of the streaming rules
// shared with Android and the JS block collector. It goes through the shared
// store, so the tick's collect, measurement and render filter once.
NSString *ENRMRenderableMarkdownForStreaming(NSString *markdown, ENRMTableStreamingMode tableMode,
                                             ENRMCodeBlockStreamingMode codeBlockMode, ENRMMediaStreamingMode mediaMode,
                                             BOOL *outEndsInsideOpenCodeFence)
{
  Markdown::StreamingFilterOptions options;
  options.tableMode = tableMode == ENRMTableStreamingModeHidden ? Markdown::StreamingBlockMode::Hidden
                                                                : Markdown::StreamingBlockMode::Progressive;
  options.codeBlockMode = codeBlockMode == ENRMCodeBlockStreamingModeHidden ? Markdown::StreamingBlockMode::Hidden
                                                                            : Markdown::StreamingBlockMode::Progressive;
  options.mediaMode = mediaMode == ENRMMediaStreamingModeHidden ? Markdown::StreamingBlockMode::Hidden
                                                                : Markdown::StreamingBlockMode::Progressive;
  std::string utf8 = ENRMUTF8String(markdown);
  Markdown::StreamingFilterResult result = Markdown::DocumentStore::shared().filter(utf8, options);
  if (outEndsInsideOpenCodeFence) {
    *outEndsInsideOpenCodeFence = result.endsInsideOpenCodeFence;
  }
  // The filter only cuts, so an equal length means nothing was cut.
  return result.markdown.size() == utf8.size() ? markdown : ENRMStringFromUTF8(result.markdown);
}
