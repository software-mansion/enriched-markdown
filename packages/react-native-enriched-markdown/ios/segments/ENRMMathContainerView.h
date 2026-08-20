#pragma once
#import "ENRMUIKit.h"
#import "StyleConfig.h"

@class ENRMAccessibilityLabels;

NS_ASSUME_NONNULL_BEGIN

@interface ENRMMathContainerView : RCTUIView

- (instancetype)initWithConfig:(StyleConfig *)config;

- (void)applyLatex:(NSString *)latex;

- (CGFloat)measureHeight:(CGFloat)maxWidth;

/// View-free math-block height for shadow-node measurement (issue #550):
/// parses the LaTeX through the same RaTeX bridge `applyLatex:` uses and
/// applies the same padding math as `measureHeight:` — including the wrapped
/// source-fallback path when RaTeX cannot parse — without creating any view.
/// Runs on the calling thread. Like every member of this class, only
/// implemented when ENRICHED_MARKDOWN_MATH is on — guard call sites.
+ (CGFloat)measureHeightForLatex:(NSString *)latex config:(StyleConfig *)config maxWidth:(CGFloat)maxWidth;

@property (nonatomic, strong) StyleConfig *config;
@property (nonatomic, copy, readonly) NSString *cachedLatex;
@property (nonatomic, strong, nullable) ENRMAccessibilityLabels *accessibilityLabels;

// Renamed getters avoid the Cocoa `copy` method family (which signals +1
// retained returns). Property names are unchanged so call sites stay the same.
@property (nonatomic, copy, nullable, getter=menuCopyLabel) NSString *copyLabel;
@property (nonatomic, copy, nullable, getter=menuCopyAsMarkdownLabel) NSString *copyAsMarkdownLabel;

@end

NS_ASSUME_NONNULL_END
