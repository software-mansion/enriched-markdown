#pragma once
#import "ENRMCodeBlockContainerView.h"
#import "EditMenuUtils.h"
#import "ParagraphStyleUtils.h"
#import "SegmentViewRegistry.h"

@class StyleConfig;
@class EnrichedMarkdownInternalText;
@class ENRMAccessibilityLabels;

NS_ASSUME_NONNULL_BEGIN

@protocol ENRMNestedSegmentHost <ENRMWritingDirectionTarget>
@property (nonatomic, copy, nullable) ENRMSelectionCopyHandler onSelectionCopy;
@property (nonatomic, strong) StyleConfig *config;
@property (nonatomic, assign) BOOL allowFontScaling;
@property (nonatomic, assign) NSLineBreakStrategy lineBreakStrategy;
@property (nonatomic, assign, readonly) BOOL childrenInsideBlockquote;
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
@property (nonatomic, copy, nullable) void (^onTaskListItemPress)(NSInteger index, BOOL checked, NSString *text);
- (void)configureNestedTextView:(EnrichedMarkdownInternalText *)view;
@end

void ENRMConfigureNestedHost(id<ENRMNestedSegmentHost> child, id<ENRMNestedSegmentHost> parent);

ENRMSegmentViewRegistry *ENRMCreateNestedSegmentRegistry(id<ENRMNestedSegmentHost> host);

NS_ASSUME_NONNULL_END
