#import <XCTest/XCTest.h>

@interface ENRMInputHitTestTests : XCTestCase
@end

@implementation ENRMInputHitTestTests {
  UIView *_input;
  UIView *_textView;
}

- (void)setUp
{
  _input = [[NSClassFromString(@"EnrichedMarkdownTextInput") alloc] initWithFrame:CGRectMake(0, 0, 200, 120)];
  _textView = [_input valueForKey:@"contentView"];
  _textView.frame = CGRectInset(_input.bounds, 20, 20);
  [_input setValue:[NSValue valueWithUIEdgeInsets:UIEdgeInsetsMake(-20, -20, -20, -20)] forKey:@"hitTestEdgeInsets"];
  XCTAssertNotNil(_textView);
}

- (void)testTouchOnTheTextStaysInTheTextView
{
  UIView *hitView = [_input hitTest:CGPointMake(100, 60) withEvent:nil];

  XCTAssertTrue([hitView isDescendantOfView:_textView]);
}

- (void)testTouchOnThePaddingReachesTheTextView
{
  XCTAssertEqual([_input hitTest:CGPointMake(100, 10) withEvent:nil], _textView);
}

- (void)testTouchInTheHitSlopAreaReachesTheTextView
{
  XCTAssertEqual([_input hitTest:CGPointMake(100, -10) withEvent:nil], _textView);
}

- (void)testTouchBeyondTheHitSlopAreaMissesTheInput
{
  XCTAssertNil([_input hitTest:CGPointMake(100, -30) withEvent:nil]);
}

@end
