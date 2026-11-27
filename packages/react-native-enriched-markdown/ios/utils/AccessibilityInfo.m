#import "AccessibilityInfo.h"
#import "RenderContext.h"

@implementation AccessibilityInfo

+ (instancetype)infoFromContext:(RenderContext *)context
{
  AccessibilityInfo *info = [[AccessibilityInfo alloc] init];
  if (info) {
    info->_headingRanges = [context.headingRanges copy];
    info->_headingLevels = [context.headingLevels copy];
    info->_linkRanges = [context.linkRanges copy];
    info->_linkURLs = [context.linkURLs copy];
    info->_imageRanges = [context.imageRanges copy];
    info->_imageAltTexts = [context.imageAltTexts copy];
    info->_listItemRanges = [context.listItemRanges copy];
    info->_listItemPositions = [context.listItemPositions copy];
    info->_listItemDepths = [context.listItemDepths copy];
    info->_listItemOrdered = [context.listItemOrdered copy];
  }
  return info;
}

static NSIndexSet *ENRMIndexesBefore(NSArray<NSValue *> *ranges, NSUInteger location)
{
  return [ranges indexesOfObjectsPassingTest:^BOOL(NSValue *value, NSUInteger index, BOOL *stop) {
    return value.rangeValue.location < location;
  }];
}

static NSArray *ENRMJoined(NSArray *head, NSIndexSet *kept, NSArray *tail)
{
  return [[head objectsAtIndexes:kept] arrayByAddingObjectsFromArray:tail];
}

static NSArray<NSValue *> *ENRMJoinedRanges(NSArray<NSValue *> *head, NSIndexSet *kept, NSArray<NSValue *> *tail,
                                            NSInteger offset)
{
  NSMutableArray<NSValue *> *ranges = [[head objectsAtIndexes:kept] mutableCopy];
  for (NSValue *value in tail) {
    NSRange range = value.rangeValue;
    range.location = (NSUInteger)((NSInteger)range.location + offset);
    [ranges addObject:[NSValue valueWithRange:range]];
  }
  return ranges;
}

- (instancetype)infoKeepingBefore:(NSUInteger)location appending:(AccessibilityInfo *)tail offset:(NSInteger)offset
{
  AccessibilityInfo *info = [[AccessibilityInfo alloc] init];
  NSIndexSet *headings = ENRMIndexesBefore(_headingRanges, location);
  info->_headingRanges = ENRMJoinedRanges(_headingRanges, headings, tail->_headingRanges, offset);
  info->_headingLevels = ENRMJoined(_headingLevels, headings, tail->_headingLevels);
  NSIndexSet *links = ENRMIndexesBefore(_linkRanges, location);
  info->_linkRanges = ENRMJoinedRanges(_linkRanges, links, tail->_linkRanges, offset);
  info->_linkURLs = ENRMJoined(_linkURLs, links, tail->_linkURLs);
  NSIndexSet *images = ENRMIndexesBefore(_imageRanges, location);
  info->_imageRanges = ENRMJoinedRanges(_imageRanges, images, tail->_imageRanges, offset);
  info->_imageAltTexts = ENRMJoined(_imageAltTexts, images, tail->_imageAltTexts);
  NSIndexSet *items = ENRMIndexesBefore(_listItemRanges, location);
  info->_listItemRanges = ENRMJoinedRanges(_listItemRanges, items, tail->_listItemRanges, offset);
  info->_listItemPositions = ENRMJoined(_listItemPositions, items, tail->_listItemPositions);
  info->_listItemDepths = ENRMJoined(_listItemDepths, items, tail->_listItemDepths);
  info->_listItemOrdered = ENRMJoined(_listItemOrdered, items, tail->_listItemOrdered);
  return info;
}

@end
