#import "ENRMUIKit.h"
#import <React/RCTViewComponentView.h>

#ifndef EnrichedMarkdownTextInput_h
#define EnrichedMarkdownTextInput_h

@class ENRMEditSession;

NS_ASSUME_NONNULL_BEGIN

@interface EnrichedMarkdownTextInput : RCTViewComponentView
@property (nonatomic, readonly) ENRMEditSession *editSession;
/// The largest content height Yoga allowed in the last measure: infinite when
/// nothing constrains the height (the input grows with its text), or the
/// max/fixed height otherwise. Set by the shadow node.
@property (nonatomic, assign) CGFloat maxContentHeight;
- (CGSize)measureSize:(CGFloat)maxWidth;
- (nullable NSString *)markdownForSelectedRange;
- (void)copyToClipboard;
- (void)pasteMarkdown:(NSString *)markdown;
- (void)replaceSelectedTextWith:(NSString *)text formattingRanges:(NSArray *)ranges;
- (void)scheduleRelayoutIfNeeded;
@end

NS_ASSUME_NONNULL_END

#endif
