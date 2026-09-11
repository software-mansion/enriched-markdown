#pragma once

#import "ENRMUIKit.h"

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

/// Returns the character index in textView's text storage corresponding to
/// the tap location, or NSNotFound if the point falls outside the text.
NSUInteger ENRMCharacterIndexForTap(ENRMPlatformTextView *textView, ENRMTapRecognizer *recognizer);

/// Returns the character index in textView's text storage corresponding to
/// the given point (in textView coordinates), or NSNotFound if out of range.
NSUInteger ENRMCharacterIndexAtPoint(ENRMPlatformTextView *textView, CGPoint point);

/// Like ENRMCharacterIndexAtPoint, but also returns NSNotFound when the point
/// lies outside the text's actual bounds (e.g. past the end of a line).
NSUInteger ENRMCharacterIndexAtPointStrict(ENRMPlatformTextView *textView, CGPoint point);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
