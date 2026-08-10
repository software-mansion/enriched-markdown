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

#ifdef __cplusplus
extern "C" {
#endif

NSString *ENRMRenderableMarkdownForStreaming(NSString *markdown, ENRMTableStreamingMode tableMode,
                                             ENRMCodeBlockStreamingMode codeBlockMode);

// Whether the markdown ends inside a still-open fenced code block.
BOOL ENRMMarkdownEndsInsideOpenCodeFence(NSString *markdown);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
