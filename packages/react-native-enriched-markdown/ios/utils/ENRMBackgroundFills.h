#pragma once
#import "ENRMUIKit.h"

NS_ASSUME_NONNULL_BEGIN

/// Receives one piece of a code block, inline code or blockquote box, in the coordinates of
/// the origin it was drawn at: a fill (`strokeColor` nil) or a border (`fillColor` nil) whose
/// width and line style are set on `path`. Pieces arrive in painting order.
typedef void (^ENRMBackgroundFillSink)(UIBezierPath *path, RCTUIColor *_Nullable fillColor,
                                       RCTUIColor *_Nullable strokeColor);

/// Where the background drawers (CodeBackground, CodeBlockBackground, BlockquoteBorder)
/// send their boxes.
///
/// UIKit draws a text view's selection highlight in a view beneath the text drawing, so an
/// opaque box painted with the text covers the highlight. ENRMMarkdownTextView therefore
/// collects the boxes as layers below the highlight (`Collect`) and the text pass draws only
/// the blockquote stripes (`Skip`).
typedef NS_ENUM(NSInteger, ENRMBackgroundFillMode) {
  /// Paint boxes and stripes into the current context.
  ENRMBackgroundFillModePaint = 0,
  /// Paint only the blockquote stripes; the boxes are drawn elsewhere.
  ENRMBackgroundFillModeSkip,
  /// Hand the boxes to the sink and paint nothing.
  ENRMBackgroundFillModeCollect,
};

NS_ASSUME_NONNULL_END
