#pragma once

#import <Foundation/Foundation.h>
#ifdef __cplusplus
#include <string>
#endif

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

@class ENRMMd4cFlags;

#ifdef __cplusplus
extern "C" {
#endif

// The markdown to render for the current streaming tick, from the core's
// streaming session (StreamingSession.hpp). When non-NULL,
// outEndsInsideOpenCodeFence reports whether the result ends inside a
// still-open fenced code block, and outShowsOnlyFinishedBlocks whether everything shown is
// finished (the next block is still held back).
// `tables`: whether the parser reads tables (GFM).
NSString *ENRMRenderableMarkdownForStreaming(NSString *markdown, ENRMMd4cFlags *flags, ENRMTableStreamingMode tableMode,
                                             ENRMCodeBlockStreamingMode codeBlockMode, ENRMMediaStreamingMode mediaMode,
                                             BOOL tables, BOOL *_Nullable outEndsInsideOpenCodeFence,
                                             BOOL *_Nullable outShowsOnlyFinishedBlocks);

#ifdef __cplusplus
}

// A streamingConfig mode prop: "hidden", anything else progressive. The three
// mode enums share their values.
template <typename Mode> static inline Mode ENRMStreamingModeFromString(const std::string &mode)
{
  return mode == "hidden" ? static_cast<Mode>(0) : static_cast<Mode>(1);
}
#endif

NS_ASSUME_NONNULL_END
