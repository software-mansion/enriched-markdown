#import "ENRMBlockSlotMeasurer.h"

@implementation ENRMBlockSlotMeasurer {
  ENRMBlockSlotMeasureBlock _measure;
  NSMutableDictionary<NSString *, NSValue *> *_frames;
}

- (instancetype)initWithSlotIds:(NSSet<NSString *> *)slotIds measure:(ENRMBlockSlotMeasureBlock)measure
{
  if (self = [super init]) {
    _slotIds = [slotIds copy];
    _measure = [measure copy];
    _frames = [NSMutableDictionary dictionaryWithCapacity:slotIds.count];
  }
  return self;
}

- (NSDictionary<NSString *, NSValue *> *)frames
{
  return _frames;
}

- (CGFloat)heightForSlot:(NSString *)slotId width:(CGFloat)width origin:(CGPoint)origin
{
  if (![_slotIds containsObject:slotId]) {
    return 0;
  }
  CGFloat height = MAX(_measure(slotId, width), 0);
  _frames[slotId] = ENRMBoxRect(CGRectMake(origin.x, origin.y, width, height));
  return height;
}

@end
