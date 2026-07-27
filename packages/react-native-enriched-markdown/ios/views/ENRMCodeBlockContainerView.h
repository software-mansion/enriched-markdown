#pragma once
#import "ENRMUIKit.h"
#import "StyleConfig.h"

@class MarkdownASTNode;

NS_ASSUME_NONNULL_BEGIN

@interface ENRMCodeBlockContainerView : RCTUIView

- (instancetype)initWithConfig:(StyleConfig *)config;

- (void)applyCodeBlockNode:(MarkdownASTNode *)node;

- (CGFloat)measureHeight:(CGFloat)maxWidth;

@property (nonatomic, strong) StyleConfig *config;

// Renamed getters avoid the Cocoa `copy` method family (which signals +1
// retained returns). Property names are unchanged so call sites stay the same.
@property (nonatomic, copy, nullable, getter=menuCopyLabel) NSString *copyLabel;
@property (nonatomic, copy, nullable, getter=menuCopyAsMarkdownLabel) NSString *copyAsMarkdownLabel;

@end

NS_ASSUME_NONNULL_END
