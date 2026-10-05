#import "ENRMUIKit.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

__BEGIN_DECLS

extern NSAttributedString *kNewlineAttributedString;

NSLineBreakStrategy ENRMResolveLineBreakStrategy(NSString *_Nullable strategy);
void ENRMApplyLineBreakStrategyToParagraphStyles(NSMutableAttributedString *output,
                                                 NSLineBreakStrategy lineBreakStrategy);

/// Resolves an ellipsizeMode prop value to the NSLineBreakMode used for
/// truncation on the text container (with maximumNumberOfLines). 'clip' maps to
/// NSLineBreakByClipping (truncate with no ellipsis). Defaults to tail. Mirrors
/// React Native Text's ellipsizeMode.
NSLineBreakMode ENRMResolveEllipsizeLineBreakMode(NSString *_Nullable mode);

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

/// Stamps every styled run in `range` with `NSOriginalFont` set to its own
/// `NSFont`, so a line is sized from the font the renderer chose rather than
/// from whichever font ends up drawing the glyphs.
///
/// UIKit writes this attribute itself, but only into a UITextView's storage, so
/// the view-free measurement stack never saw it and sized a line from the
/// fallback font instead. Stamping it here keeps measuring and rendering agreed.
///
/// IMPORTANT:
/// Call this last, after every font in the range is final, on any attributed
/// string handed to a layout engine. `ENRMRenderASTNodesCore` covers everything
/// built through the node renderers; the two paths that assemble their own
/// string (table cells, code block content) call it themselves.
void ENRMPinLineMetricsToStyledFonts(NSMutableAttributedString *output, NSRange range);
void applyBaselineOffset(NSMutableAttributedString *output, NSRange range);
void applyTextAlignment(NSMutableAttributedString *output, NSRange range, NSTextAlignment textAlign);
NSTextAlignment textAlignmentFromString(NSString *textAlign);

__END_DECLS

NS_ASSUME_NONNULL_END
