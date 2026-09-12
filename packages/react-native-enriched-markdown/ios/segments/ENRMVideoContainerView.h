#pragma once
#import "ENRMFeatureFlags.h"

#if ENRICHED_MARKDOWN_VIDEO

#import "ENRMUIKit.h"
#import "StyleConfig.h"

@class MarkdownASTNode;

NS_ASSUME_NONNULL_BEGIN

@interface ENRMVideoContainerView : RCTUIView
#if !TARGET_OS_OSX
                                    <UIContextMenuInteractionDelegate>
#endif

- (instancetype)initWithConfig:(StyleConfig *)config;

- (void)applyVideoNode:(MarkdownASTNode *)node;

- (void)reapplyStyle;

- (CGFloat)measureHeight:(CGFloat)maxWidth;

+ (CGFloat)measureHeightForVideoNode:(MarkdownASTNode *)node config:(StyleConfig *)config maxWidth:(CGFloat)maxWidth;

@property (nonatomic, strong) StyleConfig *config;

@property (nonatomic, copy, nullable, getter=menuCopyLabel) NSString *copyLabel;
@property (nonatomic, copy, nullable, getter=menuCopyAsMarkdownLabel) NSString *copyAsMarkdownLabel;
@property (nonatomic, assign) BOOL enableBlockContextMenu;

@end

NS_ASSUME_NONNULL_END

#endif
