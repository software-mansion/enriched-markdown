#import "FontUtils.h"
#import "RenderContext.h"
#import <React/RCTFont.h>

UIFont *cachedFontFromBlockStyle(BlockStyle *blockStyle, RenderContext *context)
{
  if (!blockStyle) {
    return nil;
  }
  if (blockStyle.cachedFont) {
    return blockStyle.cachedFont;
  }
  return [context cachedFontForSize:blockStyle.fontSize family:blockStyle.fontFamily weight:blockStyle.fontWeight];
}

CGFloat ENRMCapFontScale(CGFloat fontScale, CGFloat maxFontSizeMultiplier)
{
  // Values < 1.0 (including 0 and NaN) mean no cap is applied
  if (!isnan(maxFontSizeMultiplier) && maxFontSizeMultiplier >= 1.0) {
    return fmin(maxFontSizeMultiplier, fontScale);
  }
  return fontScale;
}

UIFontWeight ENRMFontWeightFromString(NSString *weightString)
{
  if (weightString.length == 0) {
    return UIFontWeightRegular;
  }
  if ([weightString isEqualToString:@"ultralight"] || [weightString isEqualToString:@"100"]) {
    return UIFontWeightUltraLight;
  }
  if ([weightString isEqualToString:@"thin"] || [weightString isEqualToString:@"200"]) {
    return UIFontWeightThin;
  }
  if ([weightString isEqualToString:@"light"] || [weightString isEqualToString:@"300"]) {
    return UIFontWeightLight;
  }
  if ([weightString isEqualToString:@"normal"] || [weightString isEqualToString:@"regular"] ||
      [weightString isEqualToString:@"400"]) {
    return UIFontWeightRegular;
  }
  if ([weightString isEqualToString:@"medium"] || [weightString isEqualToString:@"500"]) {
    return UIFontWeightMedium;
  }
  if ([weightString isEqualToString:@"semibold"] || [weightString isEqualToString:@"600"]) {
    return UIFontWeightSemibold;
  }
  if ([weightString isEqualToString:@"bold"] || [weightString isEqualToString:@"700"]) {
    return UIFontWeightBold;
  }
  if ([weightString isEqualToString:@"heavy"] || [weightString isEqualToString:@"800"]) {
    return UIFontWeightHeavy;
  }
  if ([weightString isEqualToString:@"black"] || [weightString isEqualToString:@"900"]) {
    return UIFontWeightBlack;
  }
  return UIFontWeightRegular;
}

#if !TARGET_OS_OSX
// The same table as Fabric's RCTFontUtils, matched case-insensitively like it.
static UIFontDescriptorSystemDesign _Nullable ENRMSystemDesignForFamily(NSString *_Nullable family)
{
  static NSDictionary<NSString *, UIFontDescriptorSystemDesign> *designs;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    designs = @{
      @"system-ui" : UIFontDescriptorSystemDesignDefault,
      @"ui-sans-serif" : UIFontDescriptorSystemDesignDefault,
      @"ui-serif" : UIFontDescriptorSystemDesignSerif,
      @"ui-rounded" : UIFontDescriptorSystemDesignRounded,
      @"ui-monospace" : UIFontDescriptorSystemDesignMonospaced,
    };
  });
  return family.length > 0 ? designs[family.lowercaseString] : nil;
}
#endif

UIFont *ENRMUpdateFont(UIFont *font, NSString *family, NSNumber *size, NSString *weight, NSString *style,
                       CGFloat scaleMultiplier)
{
#if !TARGET_OS_OSX
  UIFontDescriptorSystemDesign design = ENRMSystemDesignForFamily(family);
  if (design) {
    UIFont *base = [RCTFont updateFont:font
                            withFamily:@"System"
                                  size:size
                                weight:weight
                                 style:style
                               variant:nil
                       scaleMultiplier:scaleMultiplier];
    UIFontDescriptor *descriptor = [base.fontDescriptor fontDescriptorWithDesign:design];
    return descriptor ? [UIFont fontWithDescriptor:descriptor size:base.pointSize] : base;
  }
#endif
  return [RCTFont updateFont:font
                  withFamily:family
                        size:size
                      weight:weight
                       style:style
                     variant:nil
             scaleMultiplier:scaleMultiplier];
}
