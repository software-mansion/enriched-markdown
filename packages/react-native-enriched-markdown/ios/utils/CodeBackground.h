#pragma once
#import "ENRMUIKit.h"
#import "StyleConfig.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const CodeAttributeName;

/// The runs of `name` in `range`, each whole: a run crossing an edge of `range` is drawn as one box.
/// Walking the whole text instead, on every draw of every tile, cost more than the drawing.
FOUNDATION_EXPORT void ENRMEnumerateWholeRuns(NSAttributedString *text, NSString *name, NSRange range,
                                              void (^block)(NSRange run));

@interface CodeBackground : NSObject

- (instancetype)initWithConfig:(StyleConfig *)config;
- (void)drawBackgroundsForGlyphRange:(NSRange)glyphsToShow
                       layoutManager:(NSLayoutManager *)layoutManager
                       textContainer:(NSTextContainer *)textContainer
                             atPoint:(CGPoint)origin;

@end

NS_ASSUME_NONNULL_END
