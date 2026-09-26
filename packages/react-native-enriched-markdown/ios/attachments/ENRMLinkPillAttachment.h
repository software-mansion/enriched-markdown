#pragma once
#import "ENRMUIKit.h"

#if !TARGET_OS_OSX
@class LinkVariantConfig;

/// Presentation over the original link characters. Text storage never receives U+FFFC.
@interface ENRMLinkPillAttachment : NSTextAttachment
@property (nonatomic, readonly) CGFloat boxHeight;
@property (nonatomic, readonly) NSString *linkAccessibilityLabel;
- (instancetype)initWithLinkText:(NSString *)originalLinkText variant:(LinkVariantConfig *)variant font:(UIFont *)font;
@end

/// Stateless and shared by visible, table, and view-free TextKit stacks.
@interface ENRMLinkPillLayoutDelegate : NSObject <NSLayoutManagerDelegate>
+ (instancetype)shared;
@end

FOUNDATION_EXPORT CGRect ENRMLinkPillTextBounds(NSAttributedString *text, CGFloat width);
FOUNDATION_EXPORT void ENRMDrawLinkPillText(NSAttributedString *text, CGRect rect);
#endif
