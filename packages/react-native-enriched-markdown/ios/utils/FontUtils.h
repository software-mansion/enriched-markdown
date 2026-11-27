#import "ENRMUIKit.h"
#import <Foundation/Foundation.h>

@class BlockStyle;
@class RenderContext;

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

/** Returns a cached UIFont from BlockStyle properties via RenderContext. */
extern UIFont *cachedFontFromBlockStyle(BlockStyle *blockStyle, RenderContext *context);

/** Returns the font scale multiplier, capped by maxFontSizeMultiplier.
 *  Uses React Native's RCTFontSizeMultiplier() internally.
 *  @param maxFontSizeMultiplier Values >= 1.0 cap the result, < 1.0 means no cap. */
extern CGFloat RCTFontSizeMultiplierWithMax(CGFloat maxFontSizeMultiplier);

/** Converts a CSS-style font weight string to a UIFontWeight constant.
 *  Mirrors React Native's RCTFont table: "100"/"ultralight" through
 *  "900"/"black", plus the "normal"/"regular"/"bold"/etc. aliases.
 *  Returns UIFontWeightRegular for unrecognised or nil input. */
extern UIFontWeight ENRMFontWeightFromString(NSString *_Nullable weightString);

#ifdef __cplusplus
}
#endif

/** RCTFont's updateFont, plus the CSS generic family `ui-monospace` (the system monospaced font),
 *  which React Native's Fabric text accepts but the legacy RCTFont does not. */
@interface ENRMFont : NSObject
+ (UIFont *)updateFont:(nullable UIFont *)font
            withFamily:(nullable NSString *)family
                  size:(nullable NSNumber *)size
                weight:(nullable NSString *)weight
                 style:(nullable NSString *)style
               variant:(nullable NSArray *)variant
       scaleMultiplier:(CGFloat)scaleMultiplier;
@end

NS_ASSUME_NONNULL_END
