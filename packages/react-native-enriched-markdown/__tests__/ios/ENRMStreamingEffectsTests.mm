#import "../../ios/utils/ENRMStreamingEffects.h"
#import <XCTest/XCTest.h>

static CGFloat ENRMAlpha(UIColor *color)
{
  CGFloat alpha = 0;
  [color getRed:NULL green:NULL blue:NULL alpha:&alpha];
  return alpha;
}

@interface ENRMStreamingEffectsTests : XCTestCase
@end

@implementation ENRMStreamingEffectsTests

- (void)testAGradientFadesTheCharactersOwnColorTowardTheEnd
{
  ENRMStreamingEffects *effects = [[ENRMStreamingEffects alloc] init];
  [effects configureType:ENRMStreamingEffectGradient duration:0.2 length:4 startColor:nil endColor:nil];
  [effects noteArrivalFrom:0 to:10 at:1];
  UIColor *own = [UIColor colorWithRed:0.2 green:0.4 blue:0.6 alpha:1];
  XCTAssertEqualWithAccuracy(ENRMAlpha([effects colorForCharacterAtIndex:9 ownColor:own time:2]), 0, 0.001);
  UIColor *second = [effects colorForCharacterAtIndex:8 ownColor:own time:2];
  XCTAssertEqualWithAccuracy(ENRMAlpha(second), 0.25, 0.001);
  CGFloat red = 0;
  [second getRed:&red green:NULL blue:NULL alpha:NULL];
  XCTAssertEqualWithAccuracy(red, 0.2, 0.001);
  XCTAssertEqual([effects colorForCharacterAtIndex:2 ownColor:own time:2], own);
  XCTAssertEqual([effects animatedRangeAt:2].location, 6u);
}

- (void)testAGradientBetweenTwoColorsReplacesTheOwnColor
{
  ENRMStreamingEffects *effects = [[ENRMStreamingEffects alloc] init];
  [effects configureType:ENRMStreamingEffectGradient
                duration:0.2
                  length:4
              startColor:UIColor.blueColor
                endColor:UIColor.clearColor];
  [effects noteArrivalFrom:0 to:10 at:1];
  UIColor *oldest = [effects colorForCharacterAtIndex:6 ownColor:UIColor.blackColor time:2];
  CGFloat blue = 0;
  [oldest getRed:NULL green:NULL blue:&blue alpha:NULL];
  XCTAssertEqualWithAccuracy(blue, 1, 0.001);
  XCTAssertEqualWithAccuracy(ENRMAlpha(oldest), 0.75, 0.001);
  XCTAssertEqualWithAccuracy(ENRMAlpha([effects colorForCharacterAtIndex:5 ownColor:UIColor.blackColor time:2]), 1,
                             0.001);
}

- (void)testATintedGradientKeepsHiddenTextHidden
{
  ENRMStreamingEffects *effects = [[ENRMStreamingEffects alloc] init];
  [effects configureType:ENRMStreamingEffectGradient
                duration:0.2
                  length:4
              startColor:UIColor.blueColor
                endColor:UIColor.redColor];
  [effects noteArrivalFrom:0 to:10 at:1];
  XCTAssertEqualWithAccuracy(ENRMAlpha([effects colorForCharacterAtIndex:8 ownColor:UIColor.clearColor time:2]), 0,
                             0.001);
}

- (void)testFadingChunksKeepTheirOwnClock
{
  ENRMStreamingEffects *effects = [[ENRMStreamingEffects alloc] init];
  [effects configureType:ENRMStreamingEffectFade duration:0.2 length:20 startColor:nil endColor:nil];
  [effects noteArrivalFrom:0 to:5 at:1];
  [effects noteArrivalFrom:5 to:10 at:1.016];
  UIColor *first = [effects colorForCharacterAtIndex:2 ownColor:UIColor.blackColor time:1.1];
  UIColor *second = [effects colorForCharacterAtIndex:7 ownColor:UIColor.blackColor time:1.1];
  XCTAssertGreaterThan(ENRMAlpha(first), ENRMAlpha(second));
  XCTAssertLessThan(ENRMAlpha(first), 1);
  XCTAssertTrue([effects changesOverTimeAt:1.1]);
  XCTAssertFalse([effects changesOverTimeAt:1.3]);
}

@end
