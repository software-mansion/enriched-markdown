#pragma once
#import "ENRMUIKit.h"

#if !TARGET_OS_OSX
/** Original-color local icons; bounded shared cache, tint remains presentation-specific. */
FOUNDATION_EXPORT UIImage *_Nullable ENRMLoadLinkPillIcon(NSString *_Nullable iconUri);
#endif
