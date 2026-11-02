#pragma once
#import <QuartzCore/QuartzCore.h>

NS_ASSUME_NONNULL_BEGIN

// Keep in step with BlockSlotReveal.kt.

static const CGFloat ENRMBlockSlotNoClip = -1;

/// The tail fade's ease.
static inline CGFloat ENRMBlockSlotRevealEaseOut(CGFloat progress)
{
  return 1.0 - (1.0 - progress) * (1.0 - progress);
}

#ifdef __cplusplus
extern "C" {
#endif

/// Moves `layer` up by `offset` and clips it to `clipHeight`, with room for
/// shadows at the sides and top. A mask it did not add is left alone.
void ENRMApplyBlockSlotReveal(CALayer *layer, CGFloat offset, CGFloat clipHeight);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
