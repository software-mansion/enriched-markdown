#import "ENRMUIKit.h"
#import <React/RCTViewComponentView.h>

#ifndef EnrichedMarkdownTextInput_h
#define EnrichedMarkdownTextInput_h

@class ENRMEditSession;

NS_ASSUME_NONNULL_BEGIN

@interface EnrichedMarkdownTextInput : RCTViewComponentView
@property (nonatomic, readonly) ENRMEditSession *editSession;
/// The largest content height the input can grow to: infinite when nothing
/// constrains the height (the input grows with its text), or the max/fixed
/// height otherwise. Zero before the first measure.
@property (nonatomic, readonly) CGFloat maxContentHeight;
/// Called by the shadow node after each measure with the largest height Yoga
/// allowed and the (clamped) height the input asked for.
- (void)didMeasureWithMaxHeight:(CGFloat)maxHeight measuredHeight:(CGFloat)measuredHeight;
- (CGSize)measureSize:(CGFloat)maxWidth;
- (nullable NSString *)markdownForSelectedRange;
- (void)copyToClipboard;
- (void)pasteMarkdown:(NSString *)markdown;
- (void)replaceSelectedTextWith:(NSString *)text formattingRanges:(NSArray *)ranges;
- (void)scheduleRelayoutIfNeeded;
@end

NS_ASSUME_NONNULL_END

#endif
