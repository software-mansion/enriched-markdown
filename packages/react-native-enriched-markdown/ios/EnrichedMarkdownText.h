#import "ENRMUIKit.h"
#import "StyleConfig.h"
#import <React/RCTViewComponentView.h>

#ifdef __cplusplus
#include <string_view>
#endif

#ifndef EnrichedMarkdownTextNativeComponent_h
#define EnrichedMarkdownTextNativeComponent_h

NS_ASSUME_NONNULL_BEGIN

@interface EnrichedMarkdownText : RCTViewComponentView
@property (nonatomic, strong) StyleConfig *config;
- (CGSize)measureSize:(CGFloat)maxWidth;
- (void)renderMarkdownSynchronously:(NSString *)markdownString;
- (BOOL)hasRenderedMarkdown:(NSString *)markdown;
- (BOOL)hasRenderedWithStyleFingerprint:(size_t)fingerprint;

#ifdef __cplusplus
/// The content size the view last laid its rendered markdown out at, if it laid
/// it out for `width` and `markdown` keeps all of what it rendered; else
/// CGSizeZero. Readable from any thread without blocking (issue #550), so the
/// shadow node can take it instead of measuring a growing document again.
- (CGSize)laidOutSizeForWidth:(CGFloat)width
             pointScaleFactor:(CGFloat)pointScaleFactor
                     markdown:(std::string_view)markdown;
#endif
@end

NS_ASSUME_NONNULL_END

#endif
