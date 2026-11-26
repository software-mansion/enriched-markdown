#import "ENRMDynamicBlockProps.h"

@implementation ENRMDynamicBlockProps

- (instancetype)init
{
  self = [super init];
  if (self) {
#if !TARGET_OS_OSX
    _tableCopyAsMarkdownEnabled = YES;
#endif
    _enableLinkPreview = YES;
    _enableBlockContextMenu = YES;
    _enableCodeBlockPress = NO;
  }
  return self;
}

@end
