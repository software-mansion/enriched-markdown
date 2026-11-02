#import "../../ios/utils/ENRMAccessibilityLabels.h"
#import "../../ios/utils/MarkdownAccessibilityElementBuilder.h"
#import <XCTest/XCTest.h>

static UIAccessibilityElement *ENRMRotorTestLeaf(id container, UIAccessibilityTraits traits)
{
  UIAccessibilityElement *element = [[UIAccessibilityElement alloc] initWithAccessibilityContainer:container];
  element.accessibilityTraits = traits;
  return element;
}

@interface ENRMRotorTestSegment : UIView
@property (nonatomic, copy) NSArray *leaves;
@end

@implementation ENRMRotorTestSegment
- (BOOL)isAccessibilityElement
{
  return NO;
}
- (NSArray *)accessibilityElements
{
  return _leaves;
}
@end

@interface AccessibilityRotorTests : XCTestCase
@end

@implementation AccessibilityRotorTests

- (void)testCollectsLeavesFromSegmentsAndNestedContainersInReadingOrder
{
  ENRMRotorTestSegment *heading = [ENRMRotorTestSegment new];
  heading.leaves = @[ ENRMRotorTestLeaf(heading, UIAccessibilityTraitHeader) ];

  UIView *quote = [UIView new];
  ENRMRotorTestSegment *quoted = [ENRMRotorTestSegment new];
  quoted.leaves = @[ ENRMRotorTestLeaf(quoted, UIAccessibilityTraitLink) ];
  [quote addSubview:quoted];

  UIView *math = [UIView new];
  math.isAccessibilityElement = YES;

  UIView *hidden = [UIView new];
  hidden.accessibilityElementsHidden = YES;
  [hidden addSubview:[ENRMRotorTestSegment new]];

  NSArray *leaves =
      [MarkdownAccessibilityElementBuilder collectLeafElementsFromElements:@[ heading, quote, math, hidden ]];

  NSArray *expected = @[ heading.leaves[0], quoted.leaves[0], math ];
  XCTAssertEqualObjects(leaves, expected);
}

- (void)testBuildsHeadingAndLinkRotorsFromSegmentViews
{
  ENRMRotorTestSegment *segment = [ENRMRotorTestSegment new];
  segment.leaves = @[
    ENRMRotorTestLeaf(segment, UIAccessibilityTraitHeader), ENRMRotorTestLeaf(segment, UIAccessibilityTraitLink),
    ENRMRotorTestLeaf(segment, UIAccessibilityTraitStaticText)
  ];
  ENRMAccessibilityLabels *labels = [ENRMAccessibilityLabels new];

  NSArray *fromSegments = [MarkdownAccessibilityElementBuilder buildRotorsFromElements:@[ segment ] labels:labels];
  NSArray *fromLeaves = [MarkdownAccessibilityElementBuilder
      buildRotorsFromElements:[MarkdownAccessibilityElementBuilder collectLeafElementsFromElements:@[ segment ]]
                       labels:labels];

  XCTAssertEqual(fromSegments.count, 0u);
  XCTAssertEqual(fromLeaves.count, 2u);
}

@end
