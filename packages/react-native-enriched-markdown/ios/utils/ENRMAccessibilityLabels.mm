#import "ENRMAccessibilityLabels.h"
#include "LatexSpeech.hpp"

@implementation ENRMAccessibilityLabels

- (NSString *)mathLabelForLatex:(NSString *)latex
{
  NSString *label = self.mathEquation;
  if ([label containsString:@"{speech}"]) {
    NSString *speech = @(Markdown::spokenLatex(latex.UTF8String).c_str());
    label = [label stringByReplacingOccurrencesOfString:@"{speech}" withString:speech];
  }
  return [label stringByReplacingOccurrencesOfString:@"{latex}" withString:latex];
}

@end
