#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

#import "AccessibilityInfo.h"
#import "ENRMAccessibilityLabels.h"
#import "MarkdownAccessibilityElementBuilder.h"

@interface ENRMLaTeXSpeechTests : XCTestCase
@end

@implementation ENRMLaTeXSpeechTests {
  ENRMAccessibilityLabels *_labels;
}

- (void)setUp
{
  [super setUp];
  _labels = [[ENRMAccessibilityLabels alloc] init];
  _labels.mathEquation = @"{speech}";
}

- (void)testFormulaIsSpokenByTheSharedCore
{
  XCTAssertEqualObjects([_labels mathLabelForLatex:@"\\frac{e^x}{2}"],
                        @"fraction e to the power x over 2 end fraction");
  XCTAssertEqualObjects([_labels mathLabelForLatex:@"\\text{über}"], @"über");
  XCTAssertEqualObjects([_labels mathLabelForLatex:@""], @"");
}

- (void)testLabelTemplateResolvesBothPlaceholders
{
  _labels.mathEquation = @"Formel: {speech} ({latex})";
  XCTAssertEqualObjects([_labels mathLabelForLatex:@"x^2"], @"Formel: x squared (x^2)");

  _labels.mathEquation = @"Math: {latex}";
  XCTAssertEqualObjects([_labels mathLabelForLatex:@"x^2"], @"Math: x^2");

  _labels.mathEquation = @"Math";
  XCTAssertEqualObjects([_labels mathLabelForLatex:@"x^2"], @"Math");
}

- (UITextView *)textViewWith:(NSString *)before formula:(NSString *)latex then:(NSString *)after
{
  UITextView *textView = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, 320, 200)];
  NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:before];
  NSRange mathRange = NSMakeRange(text.length, 1);
  [text appendAttributedString:[NSAttributedString attributedStringWithAttachment:[[NSTextAttachment alloc] init]]];
  [text addAttribute:@"mathLatex" value:latex range:mathRange];
  [text appendAttributedString:[[NSAttributedString alloc] initWithString:after]];
  textView.attributedText = text;
  return textView;
}

- (NSArray<UIAccessibilityElement *> *)elementsFor:(UITextView *)textView info:(AccessibilityInfo *)info
{
  return [MarkdownAccessibilityElementBuilder buildElementsForTextView:textView
                                                                  info:info
                                                                labels:_labels
                                                             container:textView];
}

- (void)testInlineFormulaBecomesItsOwnElement
{
  UITextView *textView = [self textViewWith:@"Energy " formula:@"E = mc^2" then:@" is famous\n"];
  NSArray *elements = [self elementsFor:textView info:[[AccessibilityInfo alloc] init]];

  XCTAssertEqualObjects([elements valueForKey:@"accessibilityLabel"],
                        (@[ @"Energy", @"E equals m c squared", @"is famous" ]));
}

- (void)testFormulaInsideLinkIsSpokenWithinTheLink
{
  UITextView *textView = [self textViewWith:@"see " formula:@"x^2" then:@" here\n"];
  AccessibilityInfo *info = [[AccessibilityInfo alloc] init];
  [info setValue:@[ [NSValue valueWithRange:NSMakeRange(0, 10)] ] forKey:@"linkRanges"];
  [info setValue:@[ @"https://example.com" ] forKey:@"linkURLs"];
  NSArray<UIAccessibilityElement *> *elements = [self elementsFor:textView info:info];

  XCTAssertEqualObjects([elements valueForKey:@"accessibilityLabel"], @[ @"see x squared here" ]);
  XCTAssertTrue(elements.firstObject.accessibilityTraits & UIAccessibilityTraitLink);
}

@end
