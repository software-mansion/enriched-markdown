#pragma once

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Measures a block slot's React child at a given width; returns its height.
typedef CGFloat (^ENRMBlockSlotMeasureBlock)(NSString *slotId, CGFloat width);

/// Boxes a CGRect into an NSValue. `+valueWithCGRect:` / `-CGRectValue` are UIKit-only, so the
/// measurer and the shadow node both go through these two helpers to stay paired on macOS.
static inline NSValue *ENRMBoxRect(CGRect rect)
{
  return [NSValue valueWithBytes:&rect objCType:@encode(CGRect)];
}

static inline CGRect ENRMUnboxRect(NSValue *value)
{
  CGRect rect = CGRectZero;
  [value getValue:&rect size:sizeof(rect)];
  return rect;
}

/**
 * Hands the shadow node's slot children to the view-free measurement walk. The
 * walk asks for each slot's height at the width and origin it lays the slot out
 * at (origin relative to the host's content box), and the measurer keeps the
 * resulting frames so the shadow node can place the children afterwards.
 */
@interface ENRMBlockSlotMeasurer : NSObject

- (instancetype)initWithSlotIds:(NSSet<NSString *> *)slotIds measure:(ENRMBlockSlotMeasureBlock)measure;

/// The ids the host must parse with (`activeBlockSlotIds`).
@property (nonatomic, copy, readonly) NSSet<NSString *> *slotIds;

/// Frames (as CGRect NSValues) of the slots the walk placed, by id.
@property (nonatomic, readonly) NSDictionary<NSString *, NSValue *> *frames;

- (CGFloat)heightForSlot:(NSString *)slotId width:(CGFloat)width origin:(CGPoint)origin;

@end

NS_ASSUME_NONNULL_END
