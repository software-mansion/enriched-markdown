#import "ENRMUIKit.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

__BEGIN_DECLS

extern NSAttributedString *kNewlineAttributedString;

NSLineBreakStrategy ENRMResolveLineBreakStrategy(NSString *_Nullable strategy);
void ENRMApplyLineBreakStrategyToParagraphStyles(NSMutableAttributedString *output,
                                                 NSLineBreakStrategy lineBreakStrategy);

/// Auto/LTR/RTL match React Native's writingDirection prop.
/// FirstStrong is the library extension: resolve each paragraph from its first strong
/// directional character (matches Android's TEXT_DIRECTION_FIRST_STRONG).
typedef NS_ENUM(NSInteger, ENRMWritingDirectionMode) {
  ENRMWritingDirectionModeAuto,
  ENRMWritingDirectionModeLTR,
  ENRMWritingDirectionModeRTL,
  ENRMWritingDirectionModeFirstStrong,
};

ENRMWritingDirectionMode ENRMResolveWritingDirectionMode(NSString *_Nullable value);

void ENRMApplyWritingDirectionToParagraphStyles(NSMutableAttributedString *output, NSWritingDirection writingDirection);

NSWritingDirection ENRMFirstStrongDirection(NSString *text);

/// Paragraphs without a strong character fall back to `fallback`. Code blocks are skipped.
void ENRMApplyFirstStrongParagraphDirections(NSMutableAttributedString *output, NSWritingDirection fallback);

/// Falls back to the app's UI layout direction when the style is missing or Natural.
BOOL ENRMParagraphIsRTL(NSParagraphStyle *_Nullable style);

/// Dispatch entry point used after every render pass. `layoutDirection` is the
/// fallback for FirstStrong neutral paragraphs and is unused for the other modes.
void ENRMApplyWritingDirectionMode(NSMutableAttributedString *output, ENRMWritingDirectionMode mode,
                                   NSWritingDirection layoutDirection);

NSMutableParagraphStyle *getOrCreateParagraphStyle(NSMutableAttributedString *output, NSUInteger index);
void applyParagraphSpacingAfter(NSMutableAttributedString *output, NSUInteger start, CGFloat marginBottom);
NSUInteger applyParagraphSpacingBefore(NSMutableAttributedString *output, NSRange range, CGFloat marginTop);
NSUInteger applyBlockSpacingBefore(NSMutableAttributedString *output, NSUInteger insertionPoint, CGFloat marginTop);
void applyBlockSpacingAfter(NSMutableAttributedString *output, CGFloat marginBottom);
void applyLineHeight(NSMutableAttributedString *output, NSRange range, CGFloat lineHeight);
void applyBaselineOffset(NSMutableAttributedString *output, NSRange range);

/// True when the range contains a block (non-inline) image attachment. Lines holding
/// such attachments must not be clamped by maximumLineHeight or the image box
/// overflows the line and paints over surrounding content.
BOOL ENRMRangeContainsBlockImage(NSAttributedString *output, NSRange range);
void applyTextAlignment(NSMutableAttributedString *output, NSRange range, NSTextAlignment textAlign);
NSTextAlignment textAlignmentFromString(NSString *textAlign);

__END_DECLS

NS_ASSUME_NONNULL_END
