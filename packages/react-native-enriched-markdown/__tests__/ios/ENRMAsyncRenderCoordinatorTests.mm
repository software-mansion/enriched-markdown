#import "../../ios/utils/ENRMAsyncRenderCoordinator.h"
#import <XCTest/XCTest.h>

@interface ENRMAsyncRenderCoordinatorTests : XCTestCase
@end

@implementation ENRMAsyncRenderCoordinatorTests {
  ENRMAsyncRenderCoordinator *_coordinator;
  NSMutableArray<NSString *> *_renders;
  NSMutableArray<NSString *> *_applies;
  dispatch_semaphore_t _releaseInFlight;
}

- (void)setUp
{
  [super setUp];
  _coordinator = [[ENRMAsyncRenderCoordinator alloc] initWithQueueLabel:"enrm.tests.render"];
  _renders = [NSMutableArray new];
  _applies = [NSMutableArray new];
  _releaseInFlight = dispatch_semaphore_create(0);

  // Park a render on the queue so every later call stays pending until the test releases it.
  dispatch_semaphore_t started = dispatch_semaphore_create(0);
  dispatch_semaphore_t releaseInFlight = _releaseInFlight;
  NSMutableArray<NSString *> *renders = _renders;
  NSMutableArray<NSString *> *applies = _applies;
  [_coordinator
      scheduleRender:^BOOL {
        [renders addObject:@"in-flight"];
        dispatch_semaphore_signal(started);
        dispatch_semaphore_wait(releaseInFlight, DISPATCH_TIME_FOREVER);
        return YES;
      }
      apply:^{ [applies addObject:@"in-flight"]; }];
  XCTAssertEqual(dispatch_semaphore_wait(started, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)), 0L);
}

- (void)tearDown
{
  dispatch_semaphore_signal(_releaseInFlight);
  [super tearDown];
}

- (void)scheduleRevision:(NSString *)name onApply:(dispatch_block_t)onApply
{
  NSMutableArray<NSString *> *renders = _renders;
  NSMutableArray<NSString *> *applies = _applies;
  [_coordinator
      scheduleRender:^BOOL {
        [renders addObject:name];
        return YES;
      }
      apply:^{
        [applies addObject:name];
        if (onApply)
          onApply();
      }];
}

- (void)testBurstRendersOnlyTheLatestRevision
{
  XCTestExpectation *applied = [self expectationWithDescription:@"latest revision applied"];
  [self scheduleRevision:@"revision 1" onApply:nil];
  [self scheduleRevision:@"revision 2" onApply:nil];
  [self scheduleRevision:@"revision 3" onApply:^{ [applied fulfill]; }];

  dispatch_semaphore_signal(_releaseInFlight);
  [self waitForExpectations:@[ applied ] timeout:5];

  XCTAssertEqualObjects(_renders, (@[ @"in-flight", @"revision 3" ]));
  XCTAssertEqualObjects(_applies, @[ @"revision 3" ]);
}

- (void)testSupersededPendingRenderIsReleasedBeforeItRuns
{
  __weak NSObject *weakDocument;
  @autoreleasepool {
    NSObject *document = [NSObject new];
    weakDocument = document;
    [_coordinator scheduleRender:^BOOL { return document != nil; } apply:^{}];
  }
  @autoreleasepool {
    XCTAssertNotNil(weakDocument);
  }

  [self scheduleRevision:@"latest" onApply:nil];

  XCTAssertNil(weakDocument);
}

- (void)testInvalidateDropsThePendingRender
{
  [self scheduleRevision:@"recycled" onApply:nil];
  [_coordinator invalidate];
  dispatch_semaphore_signal(_releaseInFlight);

  XCTestExpectation *applied = [self expectationWithDescription:@"next revision applied"];
  [self scheduleRevision:@"next" onApply:^{ [applied fulfill]; }];
  [self waitForExpectations:@[ applied ] timeout:5];

  XCTAssertEqualObjects(_renders, (@[ @"in-flight", @"next" ]));
  XCTAssertEqualObjects(_applies, @[ @"next" ]);
}

@end
