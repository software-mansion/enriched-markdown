#import "ENRMMarkdownSerializer.h"
#import "ENRMInputCoreBridge.hpp"

@implementation ENRMMarkdownSerializer

+ (NSString *)serializePlainText:(NSString *)text ranges:(NSArray<ENRMFormattingRange *> *)ranges
{
  return [self serializePlainText:text ranges:ranges blockRanges:@[]];
}

+ (NSString *)serializePlainText:(NSString *)text
                          ranges:(NSArray<ENRMFormattingRange *> *)ranges
                     blockRanges:(NSArray<ENRMBlockRange *> *)blockRanges
{
  if (text.length == 0) {
    return @"";
  }
  std::u16string markdown = Markdown::Input::serialize(
      ENRMInputCoreBridge::toU16(text), ENRMInputCoreBridge::toCore(ranges), ENRMInputCoreBridge::toCore(blockRanges));
  return ENRMInputCoreBridge::toNSString(markdown);
}

@end
