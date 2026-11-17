#import "ENRMCapture.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#if !TARGET_OS_OSX
// drawViewHierarchyInRect: renders nothing for a view taller or wider than this, in pixels (iOS 26 on
// an iPhone 15 Pro and the simulator). Too high wastes the drawing for a capture that fails; too low
// leaves a capture with what is near the screen. For snapshot views it only caps the drawing.
static const CGFloat kENRMMaxCapturePixels = 8192;

static NSHashTable<id<ENRMCaptureParticipant>> *ENRMCaptureParticipants;

// Has the participants draw what a capture of `view` shows, and returns the ones to end it; nil when
// there are none.
static NSArray<id<ENRMCaptureParticipant>> *ENRMBeginCapture(UIView *view, BOOL afterUpdates)
{
  if (!NSThread.isMainThread) {
    return nil;
  }
  UIWindow *window = view.window;
  CGFloat scale = window.screen.scale;
  CGSize size = view.bounds.size;
  if (window == nil || scale <= 0 || MAX(size.width, size.height) * scale > kENRMMaxCapturePixels) {
    return nil;
  }
  NSMutableArray<id<ENRMCaptureParticipant>> *begun = nil;
  BOOL added = NO;
  for (id<ENRMCaptureParticipant> participant in ENRMCaptureParticipants.allObjects) {
    ENRMCaptureCoverage coverage = [participant beginCaptureOfView:view];
    if (coverage != ENRMCaptureCoverageNone) {
      begun = begun ?: [NSMutableArray array];
      [begun addObject:participant];
      added = added || coverage == ENRMCaptureCoverageAdded;
    }
  }
  // Without screen updates the capture shows what was last committed: what was drawn for it too.
  // Inside an explicit transaction, or a capture made during a commit (from layout or drawing), the
  // flush waits, and the capture misses that.
  if (added && !afterUpdates) {
    [CATransaction flush];
  }
  return begun;
}

static void ENRMEndCapture(NSArray<id<ENRMCaptureParticipant>> *begun)
{
  for (id<ENRMCaptureParticipant> participant in begun) {
    [participant endCapture];
  }
}

// The captures that go through the render server: drawViewHierarchyInRect: and the snapshot views,
// which keep what they captured.
static void ENRMHookCaptures(void)
{
  Class viewClass = [UIView class];
  SEL drawSelector = @selector(drawViewHierarchyInRect:afterScreenUpdates:);
  Method draw = class_getInstanceMethod(viewClass, drawSelector);
  BOOL (*drawOriginal)(id, SEL, CGRect, BOOL) = (BOOL (*)(id, SEL, CGRect, BOOL))method_getImplementation(draw);
  method_setImplementation(draw, imp_implementationWithBlock(^BOOL(UIView *view, CGRect rect, BOOL afterUpdates) {
                             NSArray<id<ENRMCaptureParticipant>> *begun = ENRMBeginCapture(view, afterUpdates);
                             @try {
                               return drawOriginal(view, drawSelector, rect, afterUpdates);
                             } @finally {
                               ENRMEndCapture(begun);
                             }
                           }));

  SEL snapshotSelector = @selector(snapshotViewAfterScreenUpdates:);
  Method snapshot = class_getInstanceMethod(viewClass, snapshotSelector);
  UIView *(*snapshotOriginal)(id, SEL, BOOL) = (UIView * (*)(id, SEL, BOOL)) method_getImplementation(snapshot);
  method_setImplementation(snapshot, imp_implementationWithBlock(^UIView *(UIView *view, BOOL afterUpdates) {
                             NSArray<id<ENRMCaptureParticipant>> *begun = ENRMBeginCapture(view, afterUpdates);
                             @try {
                               return snapshotOriginal(view, snapshotSelector, afterUpdates);
                             } @finally {
                               ENRMEndCapture(begun);
                             }
                           }));

  SEL resizableSelector = @selector(resizableSnapshotViewFromRect:afterScreenUpdates:withCapInsets:);
  Method resizable = class_getInstanceMethod(viewClass, resizableSelector);
  UIView *(*resizableOriginal)(id, SEL, CGRect, BOOL, UIEdgeInsets) =
      (UIView * (*)(id, SEL, CGRect, BOOL, UIEdgeInsets)) method_getImplementation(resizable);
  method_setImplementation(resizable, imp_implementationWithBlock(^UIView *(UIView *view, CGRect rect,
                                                                            BOOL afterUpdates, UIEdgeInsets insets) {
                             NSArray<id<ENRMCaptureParticipant>> *begun = ENRMBeginCapture(view, afterUpdates);
                             @try {
                               return resizableOriginal(view, resizableSelector, rect, afterUpdates, insets);
                             } @finally {
                               ENRMEndCapture(begun);
                             }
                           }));
}

void ENRMCaptureAddParticipant(id<ENRMCaptureParticipant> participant)
{
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    ENRMCaptureParticipants = [NSHashTable weakObjectsHashTable];
    ENRMHookCaptures();
  });
  [ENRMCaptureParticipants addObject:participant];
}
#endif
