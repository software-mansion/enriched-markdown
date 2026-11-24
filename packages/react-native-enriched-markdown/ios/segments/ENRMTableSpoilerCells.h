#pragma once

#import "ENRMSpoilerOverlayView.h"
#import "ENRMUIKit.h"

@class StyleConfig;

NS_ASSUME_NONNULL_BEGIN

typedef CGRect (^ENRMTableCellTextRect)(NSUInteger row, NSUInteger column, CGRect *cellRect);

@interface ENRMTableSpoilerCells : NSObject

- (instancetype)initWithHost:(RCTUIView *)host;
- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, strong, nullable) StyleConfig *config;
@property (nonatomic, assign) ENRMSpoilerOverlay spoilerOverlay;

- (void)syncWithTexts:(NSArray<NSArray<NSAttributedString *> *> *)texts
          backgrounds:(NSArray<RCTUIColor *> *)backgrounds;

- (void)layoutWithTextRect:(ENRMTableCellTextRect)textRect;

- (void)setOpacityOfRows:(CGFloat (^)(NSUInteger row))opacityOfRow;

- (BOOL)revealAtPoint:(CGPoint)point;

- (BOOL)hasSpoilerAtPoint:(CGPoint)point;

@end

NS_ASSUME_NONNULL_END
