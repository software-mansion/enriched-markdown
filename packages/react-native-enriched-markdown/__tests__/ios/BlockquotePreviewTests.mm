#import "../../ios/segments/ENRMBlockquoteContainerView.h"
#import "../../ios/styles/StyleConfig.h"
#import <XCTest/XCTest.h>

@interface ENRMBlockquoteContainerView (BlockquotePreviewTests)
- (UITargetedPreview *)blockPreview;
@end

@interface ENRMBlockquotePreviewTests : XCTestCase
@end

@implementation ENRMBlockquotePreviewTests

// A lifted quote is backed by what is drawn behind it, so a quote without a fill of its own isn't
// drawn over the dimmed screen. React Native mounts a bubble's children as its siblings, so the
// bubble here sits next to the quote, not above it.
- (void)testTheLiftIsBackedByWhatIsDrawnBehindTheQuote
{
  UIWindow *window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 320, 200)];
  window.backgroundColor = [UIColor whiteColor];
  window.hidden = NO;
  UIView *container = [[UIView alloc] initWithFrame:window.bounds];
  UIView *bubble = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 80)];
  bubble.backgroundColor = [UIColor colorWithRed:0 green:0 blue:1 alpha:0.5];
  ENRMBlockquoteContainerView *quote = [[ENRMBlockquoteContainerView alloc] initWithConfig:[[StyleConfig alloc] init]];
  quote.frame = CGRectMake(10, 10, 300, 50);
  [window addSubview:container];
  [container addSubview:bubble];
  [container addSubview:quote];

  CGFloat red, green, blue, alpha;
  XCTAssertTrue([[quote blockPreview].parameters.backgroundColor getRed:&red green:&green blue:&blue alpha:&alpha]);
  XCTAssertEqualWithAccuracy(red, 0.5, 0.01);
  XCTAssertEqualWithAccuracy(green, 0.5, 0.01);
  XCTAssertEqualWithAccuracy(blue, 1, 0.01);
  XCTAssertEqualWithAccuracy(alpha, 1, 0.01);
  XCTAssertFalse(quote.layer.hidden);

  // Removed while the menu is up: no targeted preview, so UIKit uses its own fade.
  [quote removeFromSuperview];
  XCTAssertNil([quote blockPreview]);
  window.hidden = YES;
}

@end
