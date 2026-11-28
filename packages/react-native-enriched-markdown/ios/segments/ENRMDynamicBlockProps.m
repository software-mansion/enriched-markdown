#import "ENRMDynamicBlockProps.h"

@implementation ENRMDynamicBlockProps

- (instancetype)init
{
  self = [super init];
  if (self) {
    _enableLinkPreview = YES;
    _enableBlockContextMenu = YES;
    _enableCodeBlockPress = NO;
#if !TARGET_OS_OSX
    _copyTableLabel = @"Copy Table";
    _copyTableAsMarkdownLabel = @"Copy Table as Markdown";
#endif
  }
  return self;
}

@end
