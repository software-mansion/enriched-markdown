#pragma once
#import "ENRMUIKit.h"

#if !TARGET_OS_OSX
NS_ASSUME_NONNULL_BEGIN

/**
 * The icon of a link variant's `inlineIcon`, drawn before the link's own text. In text
 * storage it is one placeholder character followed by a word joiner that keeps it on the
 * line of the first word. Neither character belongs to the link text: ENRMLinkPillText.h
 * drops both wherever text leaves the view.
 */
@interface ENRMLinkIconAttachment : NSTextAttachment
/// Called on the main thread when an asynchronously loaded icon settles. For hosts that draw the
/// string themselves (the table grid) and have no text view for the attachment to invalidate.
@property (nonatomic, copy, nullable) void (^onIconLoaded)(void);

- (instancetype)initWithIconUri:(NSString *)iconUri
                  iconTintColor:(nullable UIColor *)iconTintColor
                           font:(nullable UIFont *)font
                 requestHeaders:(nullable NSDictionary<NSString *, NSString *> *)requestHeaders;

- (void)adoptFont:(nullable UIFont *)font;
@end

NS_ASSUME_NONNULL_END
#endif
