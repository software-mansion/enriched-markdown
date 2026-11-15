#import "../../ios/utils/ENRMRenderPacer.h"
#import <XCTest/XCTest.h>

// Frames are driven by hand: the display link only ticks while the run loop spins.
@interface ENRMRenderPacer (Testing)
- (void)tick:(CFTimeInterval)frameDuration;
@end

static const CFTimeInterval kPacerTestFrame = 1.0 / 60;

@interface ENRMRenderPacerTests : XCTestCase
@end

@implementation ENRMRenderPacerTests {
  ENRMRenderPacer *_pacer;
  NSInteger _renders;
  BOOL _renderStarts;
}

- (void)setUp
{
  [super setUp];
  _renders = 0;
  _renderStarts = YES;
  __weak ENRMRenderPacerTests *weakSelf = self;
  _pacer = [[ENRMRenderPacer alloc] initWithRender:^BOOL {
    ENRMRenderPacerTests *strongSelf = weakSelf;
    if (strongSelf == nil) {
      return NO;
    }
    strongSelf->_renders++;
    return strongSelf->_renderStarts;
  }];
}

- (void)testRendersOnTheNextFrameNotAtOnce
{
  [_pacer requestRender];
  XCTAssertEqual(_renders, 0);
  [_pacer tick:kPacerTestFrame];
  XCTAssertEqual(_renders, 1);
}

- (void)testUpdatesBeforeAFrameRenderOnce
{
  [_pacer requestRender];
  [_pacer requestRender];
  [_pacer requestRender];
  [_pacer tick:kPacerTestFrame];
  [_pacer tick:kPacerTestFrame];
  XCTAssertEqual(_renders, 1);
}

- (void)testTheNextRenderWaitsUntilTheLastHasApplied
{
  [_pacer requestRender];
  [_pacer tick:kPacerTestFrame];
  [_pacer requestRender];
  [_pacer tick:kPacerTestFrame];
  [_pacer tick:kPacerTestFrame];
  XCTAssertEqual(_renders, 1);

  [_pacer renderAppliedIn:0.001];
  [_pacer tick:kPacerTestFrame];
  XCTAssertEqual(_renders, 2);
}

- (void)testASlowApplySpacesRendersOutAndFastOnesBringThemBack
{
  [_pacer requestRender];
  [_pacer tick:kPacerTestFrame];
  [_pacer renderAppliedIn:kPacerTestFrame];
  // The stride counts from the render after the slow apply.
  [_pacer requestRender];
  [_pacer tick:kPacerTestFrame];
  XCTAssertEqual(_renders, 2);
  [_pacer renderAppliedIn:0.001];
  [_pacer requestRender];
  [_pacer tick:kPacerTestFrame];
  XCTAssertEqual(_renders, 2, @"a frame skipped");
  [_pacer tick:kPacerTestFrame];
  XCTAssertEqual(_renders, 3);

  for (int i = 0; i < 8; i++) {
    [_pacer renderAppliedIn:0.001];
    [_pacer requestRender];
    [_pacer tick:kPacerTestFrame];
    [_pacer tick:kPacerTestFrame];
  }
  [_pacer renderAppliedIn:0.001];
  NSInteger renders = _renders;
  [_pacer requestRender];
  [_pacer tick:kPacerTestFrame];
  XCTAssertEqual(_renders, renders + 1, @"every frame again after healthy applies");
}

- (void)testCancelDropsTheWaitingRenderAndTheOneInFlight
{
  [_pacer requestRender];
  [_pacer cancel];
  [_pacer tick:kPacerTestFrame];
  XCTAssertEqual(_renders, 0);

  [_pacer requestRender];
  [_pacer tick:kPacerTestFrame];
  [_pacer cancel];
  [_pacer requestRender];
  [_pacer tick:kPacerTestFrame];
  XCTAssertEqual(_renders, 2, @"a render outside the pacing frees the next");
}

- (void)testARequestWhileOneIsInFlightRendersAfterItsApply
{
  [_pacer requestRender];
  [_pacer tick:kPacerTestFrame];
  [_pacer requestRender];
  [_pacer renderAppliedIn:0.001];
  [_pacer tick:kPacerTestFrame];
  XCTAssertEqual(_renders, 2);
}

- (void)testTheStrideStopsAtEveryFourthFrame
{
  for (int i = 0; i < 6; i++) {
    [_pacer requestRender];
    while (_renders == i) {
      [_pacer tick:kPacerTestFrame];
    }
    [_pacer renderAppliedIn:kPacerTestFrame];
  }
  [_pacer requestRender];
  NSInteger frames = 0;
  while (_renders == 6) {
    [_pacer tick:kPacerTestFrame];
    frames++;
  }
  XCTAssertEqual(frames, 4);
}

- (void)testResetForgetsHeavyApplies
{
  [_pacer requestRender];
  [_pacer tick:kPacerTestFrame];
  [_pacer renderAppliedIn:kPacerTestFrame];
  [_pacer requestRender];
  [_pacer tick:kPacerTestFrame];
  [_pacer reset];
  [_pacer requestRender];
  [_pacer tick:kPacerTestFrame];
  XCTAssertEqual(_renders, 3, @"no frame skipped after a reset");
}

- (void)testARenderThatDoesNotStartHoldsNothingBack
{
  _renderStarts = NO;
  [_pacer requestRender];
  [_pacer tick:kPacerTestFrame];
  [_pacer requestRender];
  [_pacer tick:kPacerTestFrame];
  XCTAssertEqual(_renders, 2);
}

@end
