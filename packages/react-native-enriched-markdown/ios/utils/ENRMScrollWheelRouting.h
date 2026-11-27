#pragma once
#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>

typedef NS_ENUM(NSInteger, ENRMScrollWheelTarget) {
  ENRMScrollWheelTargetUndecided,
  ENRMScrollWheelTargetSelf,
  ENRMScrollWheelTargetNextResponder,
};

/// Where a horizontal block (table, code block, video) sends a macOS scroll-wheel event: to itself, or to the
/// next responder so the page keeps scrolling. A trackpad gesture is decided once, at `NSEventPhaseBegan`,
/// and every later event of it — including zero-delta ends and momentum — goes to the same target through
/// `*latch`. A mouse wheel (no phases) is decided per event. Vertical motion, or any motion over a block
/// that cannot scroll horizontally, belongs to the page.
static inline ENRMScrollWheelTarget ENRMRouteScrollWheel(ENRMScrollWheelTarget *latch, NSEventPhase phase,
                                                         NSEventPhase momentumPhase, CGFloat deltaX, CGFloat deltaY,
                                                         BOOL canScrollHorizontally)
{
  ENRMScrollWheelTarget byDeltas = canScrollHorizontally && fabs(deltaX) >= fabs(deltaY)
                                       ? ENRMScrollWheelTargetSelf
                                       : ENRMScrollWheelTargetNextResponder;
  if (phase == NSEventPhaseMayBegin) {
    *latch = ENRMScrollWheelTargetUndecided;
    return canScrollHorizontally ? ENRMScrollWheelTargetSelf : ENRMScrollWheelTargetNextResponder;
  }
  if (phase == NSEventPhaseBegan) {
    *latch = byDeltas;
    return byDeltas;
  }
  if (phase == NSEventPhaseNone && momentumPhase == NSEventPhaseNone) {
    return byDeltas;
  }
  ENRMScrollWheelTarget target = *latch != ENRMScrollWheelTargetUndecided ? *latch : byDeltas;
  if (momentumPhase & (NSEventPhaseEnded | NSEventPhaseCancelled)) {
    *latch = ENRMScrollWheelTargetUndecided;
  }
  return target;
}
#endif
