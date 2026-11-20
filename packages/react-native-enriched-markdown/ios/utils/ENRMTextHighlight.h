#pragma once
#import "ENRMUIKit.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * A range of text painted behind its glyphs. TextViewLayoutManager draws it
 * while it draws the backgrounds, so the text storage, layout, selection and
 * copied text do not change.
 */
@interface ENRMTextHighlight : NSObject

- (instancetype)initWithRange:(NSRange)range
                        color:(RCTUIColor *)color
                 borderRadius:(CGFloat)borderRadius
                      padding:(CGFloat)padding NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, readonly) NSRange range;
@property (nonatomic, readonly, strong) RCTUIColor *color;
@property (nonatomic, readonly) CGFloat borderRadius;
@property (nonatomic, readonly) CGFloat padding;

/// The same highlight over another range.
- (instancetype)highlightWithRange:(NSRange)range;

@end

#ifdef __cplusplus
extern "C" {
#endif

/// A color from a signed 32-bit ARGB integer, as React Native's processColor gives it.
RCTUIColor *ENRMColorFromARGB(int32_t argb);

/// Calls `block` with the box of each line `range` covers, in text container
/// coordinates and tight to the glyphs. Only glyphs in `glyphRange` count.
void ENRMEnumerateHighlightLineRects(NSLayoutManager *layoutManager, NSRange range, NSRange glyphRange,
                                     void (^block)(CGRect rect));

/// Fills each highlight's line boxes, padded and rounded, in order.
void ENRMDrawTextHighlights(NSArray<ENRMTextHighlight *> *highlights, NSLayoutManager *layoutManager,
                            NSRange glyphsToShow, CGPoint origin);

/// The union of `highlight`'s padded line boxes in text container coordinates,
/// or CGRectNull when none of it is laid out.
CGRect ENRMTextHighlightBounds(ENRMTextHighlight *highlight, NSLayoutManager *layoutManager);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
