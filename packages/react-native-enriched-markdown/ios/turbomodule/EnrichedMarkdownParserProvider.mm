#import "EnrichedMarkdownParserProvider.h"
#import "EnrichedMarkdownParser.h"

@implementation EnrichedMarkdownParserProvider

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
  return std::make_shared<facebook::react::EnrichedMarkdownParser>(params.jsInvoker);
}

@end
