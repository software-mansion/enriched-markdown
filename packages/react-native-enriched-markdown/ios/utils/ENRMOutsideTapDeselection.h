#pragma once
#import "ENRMUIKit.h"

NS_ASSUME_NONNULL_BEGIN

#if !TARGET_OS_OSX

/// Ends a read-only text view's selection when the user taps anywhere else in
/// its window, the way a tap away ends a selection in other iOS text. A tap
/// inside the view is left to the view's own tap handling.
///
/// A tap recognizer sits on the window only while a text view holds a
/// selection. It never cancels or delays the touches it sees, so scrolling,
/// presses and other recognizers behave as before.
@interface ENRMOutsideTapDeselection : NSObject

/// Call from the text view delegate's `textViewDidChangeSelection:`.
- (void)textViewDidChangeSelection:(UITextView *)textView;

/// Takes the recognizer off the window, e.g. when the view is recycled.
- (void)reset;

@end

#endif

NS_ASSUME_NONNULL_END
