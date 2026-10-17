#pragma once
#import "ENRMBackgroundFills.h"
#import "ENRMUIKit.h"
#import "StyleConfig.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const BlockquoteDepthAttributeName;
extern NSString *const BlockquoteBackgroundColorAttributeName;
extern NSString *const BlockquoteSpacerAttributeName;

static inline CGFloat blockquoteIndentForDepth(NSInteger depth, CGFloat levelSpacing)
{
  return depth * levelSpacing;
}

@interface BlockquoteBorder : NSObject

- (instancetype)initWithConfig:(StyleConfig *)config;

/// Where the boxes go; see ENRMBackgroundFillMode. Defaults to painting them.
@property (nonatomic) ENRMBackgroundFillMode fillMode;
/// Receives the boxes in ENRMBackgroundFillModeCollect.
@property (nonatomic, copy, nullable) ENRMBackgroundFillSink fillSink;
- (void)drawBordersForGlyphRange:(NSRange)glyphsToShow
                   layoutManager:(NSLayoutManager *)layoutManager
                   textContainer:(NSTextContainer *)textContainer
                         atPoint:(CGPoint)origin;

@end

NS_ASSUME_NONNULL_END
