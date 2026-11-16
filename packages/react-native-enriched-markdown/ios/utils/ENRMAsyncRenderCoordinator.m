#import "ENRMAsyncRenderCoordinator.h"

@implementation ENRMAsyncRenderCoordinator {
  dispatch_queue_t _queue;
  NSUInteger _currentRenderId;
  BOOL _workerScheduled;
  BOOL (^_pendingRender)(void);
  dispatch_block_t _pendingApply;
}

- (instancetype)initWithQueueLabel:(const char *)label
{
  if (self = [super init]) {
    _queue = dispatch_queue_create(label, DISPATCH_QUEUE_SERIAL);
  }
  return self;
}

- (void)scheduleRender:(BOOL (^)(void))renderBlock apply:(dispatch_block_t)applyBlock
{
  if (_blockAsyncRender)
    return;
  @synchronized(self) {
    ++_currentRenderId;
    _pendingRender = [renderBlock copy];
    _pendingApply = [applyBlock copy];
    if (_workerScheduled)
      return;
    _workerScheduled = YES;
  }
  dispatch_async(_queue, ^{
    while (YES) {
      @autoreleasepool {
        BOOL (^nextRender)(void);
        dispatch_block_t nextApply;
        NSUInteger renderId;
        @synchronized(self) {
          if (!self->_pendingRender) {
            self->_workerScheduled = NO;
            return;
          }
          nextRender = self->_pendingRender;
          nextApply = self->_pendingApply;
          renderId = self->_currentRenderId;
          self->_pendingRender = nil;
          self->_pendingApply = nil;
        }
        if (!nextRender())
          continue;
        dispatch_async(dispatch_get_main_queue(), ^{
          @synchronized(self) {
            if (renderId != self->_currentRenderId)
              return;
          }
          nextApply();
        });
      }
    }
  });
}

- (void)invalidate
{
  @synchronized(self) {
    ++_currentRenderId;
    _pendingRender = nil;
    _pendingApply = nil;
  }
}

@end
