#import "ENRMBlockSlotReveal.h"

static NSString *const kRevealMaskName = @"ENRMBlockSlotReveal";
static const CGFloat kRevealOverhang = 64;

void ENRMApplyBlockSlotReveal(CALayer *layer, CGFloat offset, CGFloat clipHeight)
{
  [CATransaction begin];
  [CATransaction setDisableActions:YES];
  layer.transform = offset == 0 ? CATransform3DIdentity : CATransform3DMakeTranslation(0, -offset, 0);
  BOOL ours = [layer.mask.name isEqualToString:kRevealMaskName];
  if (clipHeight == ENRMBlockSlotNoClip) {
    if (ours) {
      layer.mask = nil;
    }
  } else if (ours || layer.mask == nil) {
    if (!ours) {
      layer.mask = [CALayer layer];
      layer.mask.name = kRevealMaskName;
      layer.mask.backgroundColor = CGColorGetConstantColor(kCGColorBlack);
    }
    layer.mask.frame = CGRectMake(-kRevealOverhang, -kRevealOverhang, layer.bounds.size.width + kRevealOverhang * 2,
                                  clipHeight + kRevealOverhang);
  }
  [CATransaction commit];
}
