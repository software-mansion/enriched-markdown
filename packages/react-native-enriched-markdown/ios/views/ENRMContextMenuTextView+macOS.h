#pragma once
#include <TargetConditionals.h>

#if TARGET_OS_OSX
#import "ENRMUIKit.h"

typedef NSMenu *_Nullable (^ENRMContextMenuProvider)(NSMenu *baseMenu, NSTextView *textView);

/// macOS-only ENRMPlatformTextView subclass that manages context menus
/// and text deselection across sibling text views.
@interface ENRMContextMenuTextView : ENRMPlatformTextView <NSMenuDelegate>

@property (nonatomic, copy, nullable) ENRMContextMenuProvider contextMenuProvider;
/// Copies a selection the way the menu Copy does. Set by the hosting view, which knows the
/// source Markdown and style; without it the Copy key command keeps the system behavior.
@property (nonatomic, copy, nullable) void (^copySelectionHandler)(NSRange selectedRange);

@end

#endif // TARGET_OS_OSX
