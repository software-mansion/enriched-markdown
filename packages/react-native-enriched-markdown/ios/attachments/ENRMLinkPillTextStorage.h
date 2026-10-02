#pragma once
#import "ENRMUIKit.h"

#if !TARGET_OS_OSX
/// Keeps presentation attachments over original link characters through TextKit attribute fixing.
@interface ENRMLinkPillTextStorage : NSTextStorage
@end

/// An explicit TextKit 1 stack using the same storage as view-free and table layout.
FOUNDATION_EXPORT UITextView *ENRMCreateMarkdownTextView(void);
#endif
