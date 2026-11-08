#pragma once
#import <Foundation/Foundation.h>

/// Owns the serial render queue and render-ID counter used by async render pipelines.
/// Handles stale-result cancellation and main-thread dispatch automatically.
/// Set blockAsyncRender = YES before synchronous rendering to suppress queued dispatches.
@interface ENRMAsyncRenderCoordinator : NSObject

@property (nonatomic) BOOL blockAsyncRender;

- (instancetype)initWithQueueLabel:(const char *)label NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/// Runs renderBlock on the serial queue, one at a time. A call made before the previous
/// renderBlock has started replaces it, so a burst of calls renders only the newest one.
/// If renderBlock returns YES, applyBlock is dispatched on the main queue unless a newer
/// render was applied first. A newer call still pending does not hold it back: while
/// updates arrive faster than a render takes, each finished render shows instead of none.
- (void)scheduleRender:(BOOL (^)(void))renderBlock apply:(dispatch_block_t)applyBlock;

/// Drops pending work and discards the apply block of any render already in flight.
/// Use before recycling or otherwise resetting a host that owns this coordinator,
/// and before rendering synchronously, so an older async result can't land after it.
- (void)invalidate;

@end
