#pragma once
#import "ENRMDynamicBlockProps.h"
#import "ENRMUIKit.h"
#import "StyleConfig.h"

@class MarkdownASTNode;
@class ENRMAccessibilityLabels;
@class ENRMCodeBlockContainerView;

NS_ASSUME_NONNULL_BEGIN

typedef void (^ENRMCodeBlockCopyBlock)(NSString *code, NSString *language);
typedef void (^ENRMCodeBlockPressBlock)(NSString *code, NSString *language);
typedef void (^ENRMCodeBlockWrapToggleBlock)(ENRMCodeBlockContainerView *view);

@interface ENRMCodeBlockContainerView : RCTUIView

- (instancetype)initWithConfig:(StyleConfig *)config;

- (void)applyCodeBlockNode:(MarkdownASTNode *)node;

- (CGFloat)measureHeight:(CGFloat)maxWidth;

// View-free height for the shadow-node measurement pass: the same height an
// instance's measureHeight: reports for the node, without building a view.
+ (CGFloat)measureHeightForCodeBlockNode:(MarkdownASTNode *)node config:(StyleConfig *)config;

// View-free height of the node with `wrapped` on, laid out at the block width.
+ (CGFloat)measureWrappedHeightForCodeBlockNode:(MarkdownASTNode *)node
                                         config:(StyleConfig *)config
                                       maxWidth:(CGFloat)maxWidth;

@property (nonatomic, strong) StyleConfig *config;

// Header wrap toggle next to copy (iOS only); ENRMCodeBlockWrapState sets it
// from enableCodeBlockWrapToggle.
@property (nonatomic, assign) BOOL showsWrapButton;

// Wraps long lines at the block width instead of scrolling horizontally. Only
// ENRMCodeBlockWrapState writes it; the header toggle just asks through onWrapToggle.
@property (nonatomic, assign) BOOL wrapped;

// Fired when the header toggle or the VoiceOver action is used; the host flips
// `wrapped` and re-measures.
@property (nonatomic, copy, nullable) ENRMCodeBlockWrapToggleBlock onWrapToggle;

// True until the closing fence arrives: highlighting is deferred and copying is
// disabled, while the header stays visible.
@property (nonatomic, assign) BOOL pending;

// Shared, runtime-mutable block props (context-menu gate, tap gate, copy labels)
// read live at use-time. Set to the root's shared instance at creation so a code
// block added after a toggle is born current. See ENRMDynamicBlockProps.
@property (nonatomic, strong) ENRMDynamicBlockProps *dynamicProps;

// Wrap toggle labels (see ENRMAccessibilityLabels); the copy label lives on
// dynamicProps.
@property (nonatomic, strong, nullable) ENRMAccessibilityLabels *accessibilityLabels;

// Fired when the code is copied (header button, context-menu Copy, or the
// VoiceOver copy action); set by the host to bridge up to the JS onCopyPress
// event. Not fired for "Copy as Markdown".
@property (nonatomic, copy, nullable) ENRMCodeBlockCopyBlock onCopyPress;

// Bridges a whole-block tap (not the copy button) up to the JS onCodeBlockPress event.
@property (nonatomic, copy, nullable) ENRMCodeBlockPressBlock onCodeBlockPress;

@end

NS_ASSUME_NONNULL_END
