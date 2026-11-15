#import "../../ios/utils/ENRMTailFadeInAnimator.h"
#import <XCTest/XCTest.h>

// A streaming update replaces the whole attributed text and then fades in the
// new tail. Text that was already on screen can change its colour between two
// updates, e.g. "[docs" is plain text until "](url)" arrives and turns it into a
// link. The new colour must survive the next fade.
@interface ENRMTailFadeInAnimatorTests : XCTestCase
@end

@implementation ENRMTailFadeInAnimatorTests {
  UITextView *_textView;
  ENRMTailFadeInAnimator *_animator;
}

- (void)setUp
{
  _textView = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, 320, 200)];
  _animator = [[ENRMTailFadeInAnimator alloc] initWithTextView:_textView];
}

- (void)tearDown
{
  [_animator cancel];
  _animator = nil;
  _textView = nil;
}

static NSAttributedString *ENRMFadeTestText(NSString *string, UIColor *color)
{
  return [[NSAttributedString alloc] initWithString:string attributes:@{NSForegroundColorAttributeName : color}];
}

- (UIColor *)colorAt:(NSUInteger)index
{
  return [_textView.textStorage attribute:NSForegroundColorAttributeName atIndex:index effectiveRange:NULL];
}

// Starts a fade of "docs" in body colour, as it looks before the link closes.
- (void)startFadeOfPlainTail
{
  _textView.attributedText = ENRMFadeTestText(@"See docs", UIColor.blackColor);
  [_animator animateFrom:4 to:8];
  XCTAssertEqual(CGColorGetAlpha([self colorAt:4].CGColor), 0.0, @"the tail starts transparent");
}

- (void)testATailThatBecameALinkKeepsTheLinkColour
{
  [self startFadeOfPlainTail];

  NSMutableAttributedString *next = [ENRMFadeTestText(@"See docs.", UIColor.blackColor) mutableCopy];
  [next addAttribute:NSForegroundColorAttributeName value:UIColor.blueColor range:NSMakeRange(4, 4)];
  _textView.attributedText = next;
  [_animator animateFrom:8 to:9];

  XCTAssertEqualObjects([self colorAt:4], UIColor.blueColor);
}

- (void)testAnUpdateWithNoNewTailKeepsTheNewColour
{
  [self startFadeOfPlainTail];

  NSMutableAttributedString *next = [ENRMFadeTestText(@"See docs", UIColor.blackColor) mutableCopy];
  [next addAttribute:NSForegroundColorAttributeName value:UIColor.blueColor range:NSMakeRange(4, 4)];
  _textView.attributedText = next;
  [_animator animateFrom:8 to:8];

  XCTAssertEqualObjects([self colorAt:4], UIColor.blueColor);
}

- (void)testCancelStillMakesAFadingTailOpaque
{
  [self startFadeOfPlainTail];

  [_animator cancel];

  XCTAssertEqualObjects([self colorAt:4], UIColor.blackColor);
}

@end
