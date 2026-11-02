#import "../../ios/segments/ENRMBlockSlotSegmentView.h"
#import "../../ios/slots/ENRMBlockSlotReveal.h"
#import "../../ios/slots/ENRMBlockSlotRevealController.h"
#import <React/RCTUtils.h>
#import <XCTest/XCTest.h>

// A slot growing into place: the placeholder lays out its share of the height
// while measurement keeps the full one, and the slots below it move with it.
@interface ENRMFakeRevealTarget : NSObject <ENRMBlockSlotRevealTarget>
@property (nonatomic, copy) NSString *slotId;
@property (nonatomic, assign) CGFloat offset;
@property (nonatomic, assign) CGFloat clipHeight;
@end

@implementation ENRMFakeRevealTarget
- (void)setRevealOffset:(CGFloat)offset clipHeight:(CGFloat)clipHeight
{
  _offset = offset;
  _clipHeight = clipHeight;
}
@end

@interface ENRMBlockSlotRevealTests : XCTestCase
@end

@implementation ENRMBlockSlotRevealTests

- (void)testThePlaceholderLaysOutItsShareOfTheHeight
{
  const CGFloat scale = RCTScreenScale();
  ENRMBlockSlotSegmentView *placeholder = [[ENRMBlockSlotSegmentView alloc] init];
  placeholder.slotHeight = 100.4;

  const CGFloat reserved = ceil(100.4 * scale) / scale;
  XCTAssertEqual(placeholder.reservedHeight, reserved);
  XCTAssertEqual([placeholder measureHeight:320], reserved, @"measurement keeps the full height");

  placeholder.revealFraction = 0.5;
  XCTAssertEqual(placeholder.revealedHeight, round(reserved * 0.5 * scale) / scale);
  XCTAssertEqual([placeholder measureHeight:320], reserved, @"growing does not change the measurement");

  placeholder.revealFraction = 1;
  XCTAssertEqual(placeholder.revealedHeight, reserved);
}

- (void)testAMaskTheSlotDidNotAddIsLeftAlone
{
  CALayer *layer = [CALayer layer];
  CALayer *mask = [CALayer layer];
  layer.mask = mask;

  ENRMApplyBlockSlotReveal(layer, 0, 50);
  XCTAssertEqual(layer.mask, mask);
  ENRMApplyBlockSlotReveal(layer, 0, ENRMBlockSlotNoClip);
  XCTAssertEqual(layer.mask, mask);
}

- (ENRMBlockSlotSegmentView *)placeholder:(NSString *)slotId height:(CGFloat)height
{
  ENRMBlockSlotSegmentView *placeholder = [[ENRMBlockSlotSegmentView alloc] init];
  placeholder.slotId = slotId;
  placeholder.slotHeight = height;
  return placeholder;
}

- (ENRMFakeRevealTarget *)target:(NSString *)slotId
{
  ENRMFakeRevealTarget *target = [[ENRMFakeRevealTarget alloc] init];
  target.slotId = slotId;
  target.offset = -1;
  target.clipHeight = -2;
  return target;
}

- (void)testAGrowingSlotMovesTheSlotsBelowIt
{
  ENRMBlockSlotRevealController *controller = [[ENRMBlockSlotRevealController alloc] initWithFrameHandler:^{}];
  ENRMBlockSlotSegmentView *above = [self placeholder:@"image:a:0" height:100];
  ENRMBlockSlotSegmentView *below = [self placeholder:@"image:b:0" height:80];
  ENRMFakeRevealTarget *aboveTarget = [self target:above.slotId];
  ENRMFakeRevealTarget *belowTarget = [self target:below.slotId];
  ENRMFakeRevealTarget *unplaced = [self target:@"image:gone:0"];

  [controller noteHeights:@{below.slotId : @80} inSegments:@[ below ] reveal:NO];
  [controller noteHeights:@{above.slotId : @100, below.slotId : @80} inSegments:@[ above, below ] reveal:YES];
  [controller applyToSegments:@[ above, below ] slotViews:@[ aboveTarget, belowTarget, unplaced, [NSObject new] ]];

  XCTAssertLessThan(above.revealedHeight, above.reservedHeight);
  XCTAssertEqual(aboveTarget.offset, 0);
  XCTAssertEqual(aboveTarget.clipHeight, above.revealedHeight);
  XCTAssertEqual(belowTarget.offset, above.reservedHeight - above.revealedHeight);
  XCTAssertEqual(belowTarget.clipHeight, ENRMBlockSlotNoClip);
  XCTAssertEqual(unplaced.offset, 0);
  XCTAssertEqual(unplaced.clipHeight, ENRMBlockSlotNoClip);

  [controller cancel];
  [controller applyToSegments:@[ above, below ] slotViews:@[ aboveTarget, belowTarget ]];
  XCTAssertEqual(above.revealedHeight, above.reservedHeight);
  XCTAssertEqual(belowTarget.offset, 0);
  XCTAssertEqual(aboveTarget.clipHeight, ENRMBlockSlotNoClip);
}

- (void)testASlotThatLeftGrowsInAgain
{
  ENRMBlockSlotRevealController *controller = [[ENRMBlockSlotRevealController alloc] initWithFrameHandler:^{}];
  ENRMBlockSlotSegmentView *slot = [self placeholder:@"image:a:0" height:100];

  [controller noteHeights:@{slot.slotId : @100} inSegments:@[ slot ] reveal:NO];
  [controller noteHeights:@{slot.slotId : @100} inSegments:@[ slot ] reveal:YES];
  [controller applyToSegments:@[ slot ] slotViews:@[]];
  XCTAssertEqual(slot.revealFraction, 1);

  [controller keepSlotIds:[NSSet set]];
  [controller noteHeights:@{slot.slotId : @100} inSegments:@[ slot ] reveal:YES];
  [controller applyToSegments:@[ slot ] slotViews:@[]];
  XCTAssertLessThan(slot.revealFraction, 1);
  [controller cancel];
}

@end
