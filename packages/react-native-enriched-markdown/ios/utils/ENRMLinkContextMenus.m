#import "ENRMLinkContextMenus.h"

@implementation ENRMLinkContextMenus
- (instancetype)init
{
  if (self = [super init])
    _menus = @{};
  return self;
}

- (BOOL)hasMenuForURL:(NSString *)url
{
#if !TARGET_OS_OSX
  if (@available(iOS 17.0, *))
    return url != nil && [self.menus[url][@"items"] count] > 0;
#endif
  return NO;
}

#if !TARGET_OS_OSX
- (UIMenu *)menuForURL:(NSString *)url
{
  if (![self hasMenuForURL:url])
    return nil;
  NSDictionary *config = self.menus[url];
  NSMutableArray<UIAction *> *actions = [NSMutableArray array];
  __weak ENRMLinkContextMenus *weakSelf = self;
  for (NSDictionary *item in config[@"items"]) {
    NSString *text = item[@"text"];
    NSString *icon = item[@"icon"];
    UIAction *action = [UIAction actionWithTitle:text
                                           image:icon.length ? [UIImage systemImageNamed:icon] : nil
                                      identifier:nil
                                         handler:^(__kindof UIAction *action) {
                                           ENRMLinkContextMenus *strongSelf = weakSelf;
                                           if (strongSelf.onPress)
                                             strongSelf.onPress(url, text);
                                         }];
    if ([item[@"disabled"] boolValue])
      action.attributes |= UIMenuElementAttributesDisabled;
    if ([item[@"destructive"] boolValue])
      action.attributes |= UIMenuElementAttributesDestructive;
    [actions addObject:action];
  }
  return [UIMenu menuWithTitle:config[@"title"] children:actions];
}
#endif
@end
