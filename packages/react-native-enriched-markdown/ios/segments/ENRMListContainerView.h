#pragma once

#import "ENRMContainerNodeView.h"
#import "ENRMNestedSegmentViewRegistry.h"

@class ENRMCodeBlockWrapCursor;
@class ENRMBlockSlotMeasurer;

NS_ASSUME_NONNULL_BEGIN

@interface ENRMListContainerView : ENRMContainerNodeView <ENRMNestedSegmentHost>
- (instancetype)initWithConfig:(StyleConfig *)config;
- (void)applyListSegment:(ENRMListSegment *)segment;
- (CGFloat)measureHeight:(CGFloat)width;
- (BOOL)isTaskTargetAtPoint:(CGPoint)point;
+ (CGFloat)measureListSegment:(ENRMListSegment *)segment
                       config:(StyleConfig *)config
                        width:(CGFloat)width
             pointScaleFactor:(CGFloat)pointScaleFactor
             allowFontScaling:(BOOL)allowFontScaling
            lineBreakStrategy:(NSLineBreakStrategy)lineBreakStrategy
                   wrapCursor:(nullable ENRMCodeBlockWrapCursor *)wrapCursor
                 slotMeasurer:(nullable ENRMBlockSlotMeasurer *)slotMeasurer
                       origin:(CGPoint)origin;
@property (nonatomic, readonly) BOOL rootList;
@property (nonatomic, assign) ENRMWritingDirectionMode writingDirectionMode;
@property (nonatomic, assign) NSWritingDirection resolvedLayoutDirection;
@property (nonatomic, assign) NSWritingDirection outerDirection;
@property (nonatomic, copy, nullable) ENRMSelectionCopyHandler onSelectionCopy;
@property (nonatomic, assign) BOOL allowFontScaling;
@property (nonatomic, assign) NSLineBreakStrategy lineBreakStrategy;
@property (nonatomic, strong) ENRMDynamicBlockProps *dynamicProps;
@property (nonatomic, strong, nullable) ENRMAccessibilityLabels *accessibilityLabels;
@property (nonatomic, copy, nullable) void (^onLinkPress)(NSString *url);
@property (nonatomic, copy, nullable) void (^onLinkLongPress)(NSString *url);
@property (nonatomic, copy, nullable) void (^onImagePress)(NSString *url, NSString *altText);
@property (nonatomic, copy, nullable) void (^onTextPress)(NSInteger index, NSString *text);
@property (nonatomic, copy, nullable) ENRMCodeBlockCopyBlock onCopyPress;
@property (nonatomic, copy, nullable) ENRMCodeBlockPressBlock onCodeBlockPress;
@property (nonatomic, copy, nullable) RCTUIView *_Nullable (^createLeafView)(ENRMRenderedSegment *segment);
@property (nonatomic, copy, nullable) BOOL (^updateLeafView)(RCTUIView *view, ENRMRenderedSegment *segment);
@property (nonatomic, copy, nullable) BOOL (^onTaskListItemPress)(NSInteger index, BOOL checked, NSString *text);
@end

NS_ASSUME_NONNULL_END
