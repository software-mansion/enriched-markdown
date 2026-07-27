#pragma once

#import <Foundation/Foundation.h>

@class StyleConfig;

NS_ASSUME_NONNULL_BEGIN

/// Seam for the optional syntax highlighting module.
///
/// The main package never links a highlighter at compile time. An optional
/// module (planned: a tree-sitter based implementation gated the same way as
/// the math module) provides a class named ENRMCodeBlockHighlighterImpl
/// conforming to ENRMCodeBlockHighlighting; it is resolved once at runtime via
/// NSClassFromString. When the class is absent, or the highlight call returns
/// nil (unknown language, highlight failure), callers fall back to plain
/// uncolored rendering, so a missing module degrades to exactly the current
/// code block appearance.
///
/// Implementations must only vary attributes that do not affect text metrics
/// (foreground color). ENRMCodeBlockContainerView measures block height from
/// the plain attributed string, so any metric-affecting attribute would make
/// the measured height diverge from the drawn height.
@protocol ENRMCodeBlockHighlighting <NSObject>
- (nullable NSAttributedString *)highlightCode:(NSString *)code
                                      language:(nullable NSString *)language
                                        config:(StyleConfig *)config;
@end

#ifdef __cplusplus
extern "C" {
#endif

id<ENRMCodeBlockHighlighting> _Nullable ENRMResolveCodeBlockHighlighter(void);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
