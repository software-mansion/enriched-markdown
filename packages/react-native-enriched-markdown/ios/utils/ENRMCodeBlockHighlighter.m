#import "ENRMCodeBlockHighlighter.h"

id<ENRMCodeBlockHighlighting> ENRMResolveCodeBlockHighlighter(void)
{
  static id<ENRMCodeBlockHighlighting> highlighter = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    Class cls = NSClassFromString(@"ENRMCodeBlockHighlighterImpl");
    if (cls && [cls conformsToProtocol:@protocol(ENRMCodeBlockHighlighting)]) {
      highlighter = [[cls alloc] init];
    }
  });
  return highlighter;
}
