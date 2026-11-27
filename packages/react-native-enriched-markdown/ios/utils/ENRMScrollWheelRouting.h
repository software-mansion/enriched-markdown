#pragma once
#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>

typedef NS_ENUM(NSInteger, ENRMScrollWheelTarget) {
  ENRMScrollWheelTargetUndecided,
  ENRMScrollWheelTargetSelf,
  ENRMScrollWheelTargetNextResponder,
};

/// The gesture a block has decided on, and the target its momentum follows once the fingers lift.
typedef struct {
  ENRMScrollWheelTarget gesture;
  ENRMScrollWheelTarget momentum;
} ENRMScrollWheelLatch;

/// Where a horizontal block (table, code block, video) sends a macOS scroll-wheel event: to itself, or to the
/// next responder so the page keeps scrolling. A trackpad gesture is decided at its first event with motion,
/// and its later events, including the zero-delta end and the momentum that follows, go to the same target.
/// (With responsive scrolling, the view that takes the gesture's first events tracks the rest itself, so the
/// latch mostly matters for those first events and for views without a tracking loop.) A mouse wheel (no
/// phases) is decided per event. Vertical motion, or any motion over a block that cannot scroll
/// horizontally, belongs to the page.
static inline ENRMScrollWheelTarget ENRMRouteScrollWheel(ENRMScrollWheelLatch *latch, NSEventPhase phase,
                                                         NSEventPhase momentumPhase, CGFloat deltaX, CGFloat deltaY,
                                                         BOOL canScrollHorizontally)
{
  ENRMScrollWheelTarget byDeltas = canScrollHorizontally && fabs(deltaX) >= fabs(deltaY)
                                       ? ENRMScrollWheelTargetSelf
                                       : ENRMScrollWheelTargetNextResponder;
  ENRMScrollWheelTarget undecided =
      canScrollHorizontally ? ENRMScrollWheelTargetSelf : ENRMScrollWheelTargetNextResponder;

  if (momentumPhase != NSEventPhaseNone) {
    // Momentum this block's own gesture didn't leave behind belongs to the page.
    ENRMScrollWheelTarget target =
        latch->momentum != ENRMScrollWheelTargetUndecided ? latch->momentum : ENRMScrollWheelTargetNextResponder;
    if (momentumPhase & (NSEventPhaseEnded | NSEventPhaseCancelled)) {
      latch->momentum = ENRMScrollWheelTargetUndecided;
    }
    return target;
  }
  if (phase == NSEventPhaseNone) {
    return byDeltas;
  }
  // Any finger event ends the momentum of an earlier gesture.
  latch->momentum = ENRMScrollWheelTargetUndecided;
  if (phase & (NSEventPhaseMayBegin | NSEventPhaseBegan)) {
    latch->gesture = ENRMScrollWheelTargetUndecided;
  }
  if (latch->gesture == ENRMScrollWheelTargetUndecided && (deltaX != 0 || deltaY != 0)) {
    latch->gesture = byDeltas;
  }
  ENRMScrollWheelTarget target = latch->gesture != ENRMScrollWheelTargetUndecided ? latch->gesture : undecided;
  if (phase & (NSEventPhaseEnded | NSEventPhaseCancelled)) {
    latch->momentum = latch->gesture;
    latch->gesture = ENRMScrollWheelTargetUndecided;
  }
  return target;
}
#endif
