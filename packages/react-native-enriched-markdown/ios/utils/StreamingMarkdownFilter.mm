#import "StreamingMarkdownFilter.h"
#include "StreamingFilter.hpp"
#include <string>

// Thin bridge to the core's filter, the single owner of the streaming rules
// shared with Android and the JS block collector.
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
  Markdown::StreamingFilterResult result =
      Markdown::renderableMarkdownForStreaming(std::string(markdown.UTF8String ?: ""), options);
  if (outEndsInsideOpenCodeFence) {
    *outEndsInsideOpenCodeFence = result.endsInsideOpenCodeFence;
  }
  // Cuts land on line boundaries, so the bytes stay valid UTF-8.
  return [NSString stringWithUTF8String:result.markdown.c_str()] ?: @"";
}
