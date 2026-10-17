#pragma once
#import "ENRMBackgroundFills.h"
#import "ENRMUIKit.h"
#import "StyleConfig.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const CodeAttributeName;

@interface CodeBackground : NSObject

- (instancetype)initWithConfig:(StyleConfig *)config;

/// Where the boxes go; see ENRMBackgroundFillMode. Defaults to painting them.
@property (nonatomic) ENRMBackgroundFillMode fillMode;
/// Receives the boxes in ENRMBackgroundFillModeCollect.
@property (nonatomic, copy, nullable) ENRMBackgroundFillSink fillSink;
- (void)drawBackgroundsForGlyphRange:(NSRange)glyphsToShow
                       layoutManager:(NSLayoutManager *)layoutManager
                       textContainer:(NSTextContainer *)textContainer
                             atPoint:(CGPoint)origin;

@end

NS_ASSUME_NONNULL_END
