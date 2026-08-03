#pragma once
#import "ENRMUIKit.h"
#import "StyleConfig.h"

@class MarkdownASTNode;

NS_ASSUME_NONNULL_BEGIN

@interface ENRMCodeBlockContainerView : RCTUIView

- (instancetype)initWithConfig:(StyleConfig *)config;

- (void)applyCodeBlockNode:(MarkdownASTNode *)node;

- (CGFloat)measureHeight:(CGFloat)maxWidth;

// View-free height for the shadow-node measurement pass: the same height an
// instance's measureHeight: reports for the node, without building a view.
+ (CGFloat)measureHeightForCodeBlockNode:(MarkdownASTNode *)node config:(StyleConfig *)config;

@property (nonatomic, strong) StyleConfig *config;

// Renamed getters avoid the Cocoa `copy` method family (which signals +1
// retained returns). Property names are unchanged so call sites stay the same.
@property (nonatomic, copy, nullable, getter=menuCopyLabel) NSString *copyLabel;
@property (nonatomic, copy, nullable, getter=menuCopyAsMarkdownLabel) NSString *copyAsMarkdownLabel;

@end

NS_ASSUME_NONNULL_END
