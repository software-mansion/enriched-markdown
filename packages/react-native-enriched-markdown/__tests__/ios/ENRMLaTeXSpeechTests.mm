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

- (NSString *)speak:(NSString *)latex
{
  return [_labels mathLabelForLatex:latex];
}

- (void)testPowersAndIndices
{
  XCTAssertEqualObjects([self speak:@"x^2"], @"x squared");
  XCTAssertEqualObjects([self speak:@"x^3"], @"x cubed");
  XCTAssertEqualObjects([self speak:@"x^n"], @"x to the power n");
  XCTAssertEqualObjects([self speak:@"x^{n+1}"], @"x to the power of n plus 1 end power");
  XCTAssertEqualObjects([self speak:@"e^{i\\pi} + 1 = 0"], @"e to the power of i pi end power plus 1 equals 0");
  XCTAssertEqualObjects([self speak:@"x_1 \\leq y_{max}"], @"x sub 1 less than or equal to y sub max");
  XCTAssertEqualObjects([self speak:@"a_{ij}"], @"a sub i j");
  XCTAssertEqualObjects([self speak:@"x_i^2"], @"x sub i squared");
}

- (void)testFractionsAndRoots
{
  XCTAssertEqualObjects([self speak:@"\\frac{1}{3}"], @"1 over 3");
  XCTAssertEqualObjects([self speak:@"\\frac{1}{n^2}"], @"1 over n squared");
  XCTAssertEqualObjects([self speak:@"\\frac{a+b}{2}"], @"fraction a plus b over 2 end fraction");
  XCTAssertEqualObjects([self speak:@"\\sqrt{2}"], @"square root of 2");
  XCTAssertEqualObjects([self speak:@"\\sqrt{a^2+b^2}"], @"square root of a squared plus b squared end root");
  XCTAssertEqualObjects([self speak:@"\\sqrt[3]{8}"], @"cube root of 8");
  XCTAssertEqualObjects([self speak:@"\\sqrt[n]{x}"], @"root n of x");
  XCTAssertEqualObjects([self speak:@"\\binom{n}{k}"], @"n choose k");
}

- (void)testBigOperatorsWithBounds
{
  XCTAssertEqualObjects([self speak:@"\\int_0^1 x^2 \\, dx = \\frac{1}{3}"],
                        @"integral from 0 to 1 of x squared d x equals 1 over 3");
  XCTAssertEqualObjects([self speak:@"\\sum_{n=1}^{\\infty} \\frac{1}{n^2}"],
                        @"sum from n equals 1 to infinity of 1 over n squared");
  XCTAssertEqualObjects([self speak:@"\\lim_{x \\to 0} \\frac{\\sin x}{x}"],
                        @"limit as x approaches 0 of fraction sine x over x end fraction");
  XCTAssertEqualObjects([self speak:@"\\prod_{i} a_i"], @"product from i of a sub i");
  XCTAssertEqualObjects([self speak:@"f: A \\to B"], @"f colon A to B");
  XCTAssertEqualObjects([self speak:@"\\int f"], @"integral of f");
}

- (void)testSymbolsLettersAndText
{
  XCTAssertEqualObjects([self speak:@"\\alpha^2 + \\Pi"], @"alpha squared plus capital pi");
  XCTAssertEqualObjects([self speak:@"\\varepsilon > 0"], @"epsilon greater than 0");
  XCTAssertEqualObjects([self speak:@"a \\neq b"], @"a not equal to b");
  XCTAssertEqualObjects([self speak:@"\\left( a + b \\right)^2"], @"open paren a plus b close paren squared");
  XCTAssertEqualObjects([self speak:@"\\left. f \\right|_0^1"], @"f vertical bar sub 0 to the power 1");
  XCTAssertEqualObjects([self speak:@"n! \\cdot f'(x)"], @"n factorial times f prime open paren x close paren");
  XCTAssertEqualObjects([self speak:@"\\vec{v} \\cdot \\hat{n}"], @"vector v times n hat");
  XCTAssertEqualObjects([self speak:@"\\text{speed} = 5 \\, \\mathrm{m/s}"], @"speed equals 5 m over s");
  XCTAssertEqualObjects([self speak:@"x \\in \\mathbb{R}"], @"x in R");
  XCTAssertEqualObjects([self speak:@"3.14 \\approx \\pi"], @"3.14 approximately equal to pi");
}

- (void)testUnknownCommandsKeepTheirName
{
  XCTAssertEqualObjects([self speak:@"\\foo{x}"], @"foo x");
}

- (void)testScriptsReadSubBeforePowerRegardlessOfOrder
{
  XCTAssertEqualObjects([self speak:@"x^2_i"], [self speak:@"x_i^2"]);
}

- (void)testMalformedInputDoesNotCrash
{
  XCTAssertEqualObjects([self speak:@""], @"");
  for (NSString *latex in @[ @"\\frac{1}", @"x^", @"}{", @"\\", @"{", @"\\sqrt[", @"^_^" ]) {
    XCTAssertNotNil([self speak:latex]);
  }
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

- (void)testInlineFormulaBecomesItsOwnElement
{
  UITextView *textView = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, 320, 200)];
  NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:@"Energy "];
  NSRange mathRange = NSMakeRange(text.length, 1);
  [text appendAttributedString:[NSAttributedString attributedStringWithAttachment:[[NSTextAttachment alloc] init]]];
  [text addAttribute:@"mathLatex" value:@"E = mc^2" range:mathRange];
  [text appendAttributedString:[[NSAttributedString alloc] initWithString:@" is famous\n"]];
  textView.attributedText = text;

  NSArray<UIAccessibilityElement *> *elements =
      [MarkdownAccessibilityElementBuilder buildElementsForTextView:textView
                                                               info:[[AccessibilityInfo alloc] init]
                                                             labels:_labels
                                                          container:textView];

  XCTAssertEqualObjects([elements valueForKey:@"accessibilityLabel"],
                        (@[ @"Energy", @"E equals m c squared", @"is famous" ]));
}

@end
