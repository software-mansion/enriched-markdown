#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Starts streaming renders on display frames, one at a time: the next waits until the last has
/// applied, and while applying overruns the frame budget, renders space out to every 2nd–4th frame.
@interface ENRMRenderPacer : NSObject

/// `render` returns whether it started a render, which then reports back through `renderAppliedIn:`.
- (instancetype)initWithRender:(BOOL (^)(void))render;
- (instancetype)init NS_UNAVAILABLE;

/// Renders on the next frame due, unless a render is still in flight.
- (void)requestRender;
/// The render it started has applied, taking `duration` seconds on the main thread.
- (void)renderAppliedIn:(CFTimeInterval)duration;
/// A render outside the pacing supersedes the one waiting and the one in flight.
- (void)cancel;
/// Cancels, and forgets how heavy applies have been.
- (void)reset;

@end

NS_ASSUME_NONNULL_END
