#pragma once

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ENRMTableStreamingMode) {
  ENRMTableStreamingModeHidden = 0,
  ENRMTableStreamingModeProgressive,
};

typedef NS_ENUM(NSInteger, ENRMCodeBlockStreamingMode) {
  ENRMCodeBlockStreamingModeHidden = 0,
  ENRMCodeBlockStreamingModeProgressive,
};

// How a trailing image paragraph or video block is treated while streaming.
// Progressive shows it as soon as its syntax is complete; hidden waits for a
// blank line or another block after it, like a table in hidden mode.
typedef NS_ENUM(NSInteger, ENRMMediaStreamingMode) {
  ENRMMediaStreamingModeHidden = 0,
  ENRMMediaStreamingModeProgressive,
};

#ifdef __cplusplus
extern "C" {
#endif

// Filtered markdown for the current streaming tick, from the core's shared
// filter (packages/core/cpp/parser/StreamingFilter.hpp). When non-NULL,
// outEndsInsideOpenCodeFence reports whether the result ends inside a still-open
// fenced code block (the trailing block whose chrome the renderer defers).
NSString *ENRMRenderableMarkdownForStreaming(NSString *markdown, ENRMTableStreamingMode tableMode,
                                             ENRMCodeBlockStreamingMode codeBlockMode, ENRMMediaStreamingMode mediaMode,
                                             BOOL *_Nullable outEndsInsideOpenCodeFence);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
