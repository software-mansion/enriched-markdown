#pragma once
#import "ENRMUIKit.h"

NS_ASSUME_NONNULL_BEGIN

@protocol ENRMBlockSlotRevealTarget <NSObject>
@property (nonatomic, copy, readonly) NSString *slotId;
- (void)setRevealOffset:(CGFloat)offset clipHeight:(CGFloat)clipHeight;
@end

/// Grows root block slots into place. The stack lays a growing slot out at a share
/// of its height, while the shadow node places the React children at their final
/// positions, so every child below moves up by what is still missing above it.
/// Nested slots move with their container but do not grow. Keep in step with
/// BlockSlotRevealController.kt.
@interface ENRMBlockSlotRevealController : NSObject

/// `onFrame` restacks the segments while a slot grows.
- (instancetype)initWithFrameHandler:(void (^)(void))onFrame;

/// With `reveal`, a root slot getting its first height starts growing.
- (void)noteHeights:(NSDictionary<NSString *, NSNumber *> *)heights
         inSegments:(NSArray<RCTUIView *> *)segmentViews
             reveal:(BOOL)reveal;
/// A slot that leaves and comes back (a regenerated answer) grows in again.
- (void)keepSlotIds:(NSSet<NSString *> *)slotIds;
/// `slotViews` may hold other views; only reveal targets are touched.
- (void)applyToSegments:(NSArray<RCTUIView *> *)segmentViews slotViews:(NSArray *)slotViews;
- (void)cancel;
- (void)reset;

@end

NS_ASSUME_NONNULL_END
