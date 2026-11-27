#import "ENRMBlockSlotLayerView.h"

@implementation ENRMBlockSlotLayerView

#if !TARGET_OS_OSX
- (RCTUIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
  RCTUIView *hit = [super hitTest:point withEvent:event];
  return hit == self ? nil : hit;
}
#else
- (NSView *)hitTest:(NSPoint)point
{
  NSView *hit = [super hitTest:point];
  return hit == self ? nil : hit;
}
#endif

@end
