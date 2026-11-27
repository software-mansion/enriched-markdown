#import "FontUtils.h"
#import "RenderContext.h"
#import <React/RCTFont.h>
#import <React/RCTUtils.h>

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

CGFloat RCTFontSizeMultiplierWithMax(CGFloat maxFontSizeMultiplier)
{
  CGFloat multiplier = RCTFontSizeMultiplier();

  // Apply maxFontSizeMultiplier cap if >= 1.0
  // Values < 1.0 (including 0 and NaN) mean no cap is applied
  if (!isnan(maxFontSizeMultiplier) && maxFontSizeMultiplier >= 1.0) {
    return fmin(maxFontSizeMultiplier, multiplier);
  }

  return multiplier;
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

@implementation ENRMFont

+ (UIFont *)updateFont:(UIFont *)font
            withFamily:(NSString *)family
                  size:(NSNumber *)size
                weight:(NSString *)weight
                 style:(NSString *)style
               variant:(NSArray *)variant
       scaleMultiplier:(CGFloat)scaleMultiplier
{
#if !TARGET_OS_OSX
  // A restyled run (bold or italic inside code) passes its current font and no family. The system
  // monospaced face has a hidden family name that RCTFont does not recognise.
  BOOL systemMonospaced = family ? [family isEqualToString:@"ui-monospace"]
                                 : (font && [font.familyName hasPrefix:@"."] &&
                                    (font.fontDescriptor.symbolicTraits & UIFontDescriptorTraitMonoSpace));
  if (systemMonospaced) {
    UIFont *base = [RCTFont updateFont:font
                            withFamily:@"System"
                                  size:size
                                weight:weight
                                 style:style
                               variant:variant
                       scaleMultiplier:scaleMultiplier];
    UIFontDescriptor *descriptor =
        [base.fontDescriptor fontDescriptorWithDesign:UIFontDescriptorSystemDesignMonospaced];
    return descriptor ? [UIFont fontWithDescriptor:descriptor size:base.pointSize] : base;
  }
#endif
  return [RCTFont updateFont:font
                  withFamily:family
                        size:size
                      weight:weight
                       style:style
                     variant:variant
             scaleMultiplier:scaleMultiplier];
}

@end
