#pragma once
#import "ENRMUIKit.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^ENRMLinkContextMenuPressHandler)(NSString *url, NSString *itemText);

@interface ENRMLinkContextMenus : NSObject
@property (nonatomic, copy) NSDictionary<NSString *, NSDictionary *> *menus;
@property (nonatomic, copy, nullable) ENRMLinkContextMenuPressHandler onPress;
- (BOOL)hasMenuForURL:(nullable NSString *)url;
#if !TARGET_OS_OSX
- (nullable UIMenu *)menuForURL:(nullable NSString *)url;
#endif
@end

#ifdef __cplusplus
template <typename T>
static inline NSDictionary<NSString *, NSDictionary *> *ENRMParseLinkContextMenus(const T &configs)
{
  NSMutableDictionary *menus = [NSMutableDictionary dictionary];
  for (const auto &config : configs) {
    NSMutableArray *items = [NSMutableArray array];
    for (const auto &item : config.items) {
      [items addObject:@{
        @"text" : @(item.text.c_str()),
        @"icon" : @(item.icon.c_str()),
        @"disabled" : @(item.disabled),
        @"destructive" : @(item.destructive)
      }];
    }
    if (items.count > 0)
      menus[@(config.url.c_str())] = @{@"title" : @(config.title.c_str()), @"items" : items};
  }
  return menus;
}
#endif

NS_ASSUME_NONNULL_END
