#pragma once

#include <TargetConditionals.h>
#if !TARGET_OS_OSX

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^ENRMTableIOSLinkBlock)(NSString *url);

/// A link found under a point of the grid.
@interface ENRMTableIOSLinkHit : NSObject
@property (nonatomic, copy) NSString *url;
/// What the user sees the link as: its pill label, or its text.
@property (nonatomic, copy, nullable) NSString *title;
/// The link's frame in grid coordinates.
@property (nonatomic, assign) CGRect frame;
@end

@interface ENRMTableIOSRowData : NSObject
@property (nonatomic, strong) NSArray<NSAttributedString *> *cellTexts;
@property (nonatomic, strong) UIColor *backgroundColor;
@end

/// Draws the entire table grid in a single drawRect: pass, avoiding
/// per-cell UITextView allocation and the TextKit layout storms that
/// cause multi-second main-thread hangs on large tables.
@interface ENRMTableIOSGridView : UIView

@property (nonatomic, copy, nullable) ENRMTableIOSLinkBlock onLinkTap;
@property (nonatomic, copy, nullable) ENRMTableIOSLinkBlock onLinkLongTap;
/// Asked when a touch lands on a link: a link with a menu is left to the context-menu
/// interaction, so the long-press recognizer must not take that touch.
@property (nonatomic, copy, nullable) BOOL (^hasLinkContextMenu)(NSString *url);
- (nullable ENRMTableIOSLinkHit *)linkAtPoint:(CGPoint)point;

- (void)updateWithRows:(NSArray<ENRMTableIOSRowData *> *)rows
             columnWidths:(NSArray<NSNumber *> *)columnWidths
               rowHeights:(NSArray<NSNumber *> *)rowHeights
              borderColor:(UIColor *)borderColor
              borderWidth:(CGFloat)borderWidth
    horizontalCellPadding:(CGFloat)horizontalCellPadding
      verticalCellPadding:(CGFloat)verticalCellPadding
             cornerRadius:(CGFloat)cornerRadius;

- (void)fadeInRowsFrom:(NSUInteger)startRow duration:(NSTimeInterval)duration;

@end

NS_ASSUME_NONNULL_END

#endif // !TARGET_OS_OSX
