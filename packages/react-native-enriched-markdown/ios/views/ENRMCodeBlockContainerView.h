#pragma once
#import "ENRMUIKit.h"
#import "StyleConfig.h"

@class MarkdownASTNode;

NS_ASSUME_NONNULL_BEGIN

typedef void (^ENRMCodeBlockCopyBlock)(NSString *code, NSString *language);

@interface ENRMCodeBlockContainerView : RCTUIView

- (instancetype)initWithConfig:(StyleConfig *)config;

- (void)applyCodeBlockNode:(MarkdownASTNode *)node;

- (CGFloat)measureHeight:(CGFloat)maxWidth;

// View-free height for the shadow-node measurement pass: the same height an
// instance's measureHeight: reports for the node, without building a view.
+ (CGFloat)measureHeightForCodeBlockNode:(MarkdownASTNode *)node config:(StyleConfig *)config;

@property (nonatomic, strong) StyleConfig *config;

// True until the closing fence arrives: highlighting is deferred and copying is
// disabled, while the header stays visible.
@property (nonatomic, assign) BOOL pending;

// Renamed getters avoid the Cocoa `copy` method family (which signals +1
// retained returns). Property names are unchanged so call sites stay the same.
@property (nonatomic, copy, nullable, getter=menuCopyLabel) NSString *copyLabel;
@property (nonatomic, copy, nullable, getter=menuCopyAsMarkdownLabel) NSString *copyAsMarkdownLabel;

// Fired when the code is copied (header button, context-menu Copy, or the
// VoiceOver copy action); set by the host to bridge up to the JS onCopyPress
// event. Not fired for "Copy as Markdown".
@property (nonatomic, copy, nullable) ENRMCodeBlockCopyBlock onCopyPress;

@end

NS_ASSUME_NONNULL_END
