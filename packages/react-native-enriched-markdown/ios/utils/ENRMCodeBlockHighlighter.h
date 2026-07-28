#pragma once

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

/// Platform adapter over the shared C++ syntax highlighting seam
/// (cpp/highlight/CodeBlockHighlighter.hpp).
///
/// Applies token colors as foreground-color attributes onto a mutable copy of
/// the plain styled code, so highlighting can never change text metrics and
/// the block height measured from the plain string stays valid. Returns nil
/// when highlighting is unavailable (module compiled out, unknown language,
/// parse failure); callers keep the plain attributed code.
NSAttributedString *_Nullable ENRMHighlightedAttributedCode(NSAttributedString *plainCode, NSString *code,
                                                            NSString *_Nullable language);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
