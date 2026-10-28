#pragma once
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

NS_ASSUME_NONNULL_BEGIN

/// Linear progress per growing slot, with the frame handler called every frame
/// meanwhile. Keep in step with BlockSlotRevealAnimator.kt.
@interface ENRMBlockSlotRevealAnimator : NSObject

- (instancetype)initWithFrameHandler:(void (^)(void))onFrame;

- (void)startSlot:(NSString *)slotId;
/// From 0 to 1 while the slot grows, 1 for any other slot.
- (CGFloat)progressForSlot:(NSString *)slotId;
- (void)cancel;

@end

NS_ASSUME_NONNULL_END
