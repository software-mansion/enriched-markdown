#import "StreamingMarkdownFilter.h"
#include "DocumentStore.hpp"
#import "ENRMMarkdownParser.h"
#import "ENRMUTF8.h"
#include <string>

// Thin bridge to the core's streaming session, the single owner of the
// streaming rules shared with Android and the JS block collector. It goes
// through the shared store, so the tick's collect, measurement and render
// prepare once.
NSString *ENRMRenderableMarkdownForStreaming(NSString *markdown, ENRMMd4cFlags *flags, ENRMTableStreamingMode tableMode,
                                             ENRMCodeBlockStreamingMode codeBlockMode, ENRMMediaStreamingMode mediaMode,
                                             BOOL *outEndsInsideOpenCodeFence)
{
  Markdown::StreamingOptions options;
  options.blocks.tableMode = tableMode == ENRMTableStreamingModeHidden ? Markdown::StreamingBlockMode::Hidden
                                                                       : Markdown::StreamingBlockMode::Progressive;
  options.blocks.codeBlockMode = codeBlockMode == ENRMCodeBlockStreamingModeHidden
                                     ? Markdown::StreamingBlockMode::Hidden
                                     : Markdown::StreamingBlockMode::Progressive;
  options.blocks.mediaMode = mediaMode == ENRMMediaStreamingModeHidden ? Markdown::StreamingBlockMode::Hidden
                                                                       : Markdown::StreamingBlockMode::Progressive;
  options.flags = ENRMCoreMd4cFlags(flags);
  std::string utf8 = ENRMUTF8String(markdown);
  Markdown::StreamingSnapshot snapshot = Markdown::DocumentStore::shared().snapshot(utf8, options);
  if (outEndsInsideOpenCodeFence) {
    *outEndsInsideOpenCodeFence = snapshot.endsInsideOpenCodeFence;
  }
  return snapshot.markdown == utf8 ? markdown : ENRMStringFromUTF8(snapshot.markdown);
}
