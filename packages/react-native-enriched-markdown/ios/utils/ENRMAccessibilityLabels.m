#import "ENRMAccessibilityLabels.h"
#import "ENRMFeatureFlags.h"

#if ENRICHED_MARKDOWN_MATH
#if __has_include("ReactNativeEnrichedMarkdown-Swift.h")
#import "ReactNativeEnrichedMarkdown-Swift.h"
#elif __has_include(<ReactNativeEnrichedMarkdown/ReactNativeEnrichedMarkdown-Swift.h>)
#import <ReactNativeEnrichedMarkdown/ReactNativeEnrichedMarkdown-Swift.h>
#endif
#endif

@implementation ENRMAccessibilityLabels

- (NSString *)mathLabelForLatex:(NSString *)latex
{
  NSString *label = self.mathEquation;
#if ENRICHED_MARKDOWN_MATH
  if ([label containsString:@"{speech}"]) {
    label = [label stringByReplacingOccurrencesOfString:@"{speech}" withString:[ENRMLaTeXSpeech spokenFormOf:latex]];
  }
#endif
  return [label stringByReplacingOccurrencesOfString:@"{latex}" withString:latex];
}

@end
