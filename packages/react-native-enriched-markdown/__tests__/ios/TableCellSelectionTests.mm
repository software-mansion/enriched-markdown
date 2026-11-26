#import "../../ios/EnrichedMarkdown.h"
#import "../../ios/segments/ENRMTableIOSGridView.h"
#import "../../ios/segments/TableContainerView.h"
#import <XCTest/XCTest.h>
#include <react/renderer/components/EnrichedMarkdownTextSpec/Props.h>

@interface ENRMTableTouchEvent : UIEvent
@end
@implementation ENRMTableTouchEvent
- (UIEventType)type
{
  return UIEventTypeTouches;
}
@end

@interface EnrichedMarkdown (ENRMTableSelectionTestLayout)
- (void)renderMarkdownContent:(NSString *)markdown synchronously:(BOOL)synchronously;
- (CGSize)computeSegmentLayoutForWidth:(CGFloat)width applyFrames:(BOOL)applyFrames;
@end

// Apply any accidental re-render before checking the other table's view and offset.
@interface ENRMSynchronousTableTestDocument : EnrichedMarkdown
@end
@implementation ENRMSynchronousTableTestDocument
- (void)renderMarkdownContent:(NSString *)markdown synchronously:(BOOL)synchronously
{
  [super renderMarkdownContent:markdown synchronously:YES];
}
@end

@interface TableContainerView (ENRMTableSelectionTestMenu) <UIEditMenuInteractionDelegate>
@end

static ENRMTableIOSGridView *ENRMFindTableGrid(UIView *view)
{
  if ([view isKindOfClass:ENRMTableIOSGridView.class])
    return (ENRMTableIOSGridView *)view;
  for (UIView *child in view.subviews) {
    ENRMTableIOSGridView *grid = ENRMFindTableGrid(child);
    if (grid)
      return grid;
  }
  return nil;
}

@interface ENRMTableCellSelectionTests : XCTestCase
@end

@implementation ENRMTableCellSelectionTests

- (void)testBlankMenuAfterSelectionAndLocalRevocationInNestedTable
{
  UIWindow *window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 240, 400)];
  window.hidden = NO;
  EnrichedMarkdown *document = [[ENRMSynchronousTableTestDocument alloc] initWithFrame:window.bounds];
  [window addSubview:document];
  auto defaults = std::make_shared<const facebook::react::EnrichedMarkdownProps>();
  auto props = std::make_shared<facebook::react::EnrichedMarkdownProps>(*defaults);
  props->markdown =
      "| A very wide column | Another wide column | Yet another wide column |\n"
      "| --- | --- | --- |\n| A | B | C |\n\n"
      "> | A B | Empty |\n> | --- | --- |\n> | x | |";
  props->isGFM = true;
  props->selectable = true;
  props->selectionMenuConfig.copyLabel = "Copy";
  props->selectionMenuConfig.copyAsMarkdownLabel = "Copy as Markdown";
  props->selectionMenuConfig.copyAsMarkdown = true;
  [document updateProps:props oldProps:defaults];
  [document finalizeUpdates:RNComponentViewUpdateMaskProps];
  [document computeSegmentLayoutForWidth:240 applyFrames:YES];
  [document layoutIfNeeded];
  ENRMTableIOSGridView *outer = ENRMFindTableGrid(document.subviews.firstObject);
  ENRMTableIOSGridView *nested = nil;
  for (UIView *v in document.subviews) {
    ENRMTableIOSGridView *grid = ENRMFindTableGrid(v);
    if (grid && grid != outer)
      nested = grid;
  }
  XCTAssertNotNil(outer);
  XCTAssertNotNil(nested);
  if (!outer || !nested)
    return;
  UIScrollView *scroll = (UIScrollView *)outer.superview;
  scroll.contentOffset = CGPointMake(24, 0);
  // Deterministic layout with interword space, unused width/height, padding, and an empty cell.
  UIFont *font = [UIFont monospacedSystemFontOfSize:16 weight:UIFontWeightRegular];
  NSAttributedString *text = [[NSAttributedString alloc] initWithString:@"A B"
                                                             attributes:@{NSFontAttributeName : font}];
  ENRMTableIOSRowData *row = [ENRMTableIOSRowData new];
  row.cellTexts = @[ text, [[NSAttributedString alloc] initWithString:@""] ];
  row.backgroundColor = UIColor.whiteColor;
  nested.frame = CGRectMake(0, 0, 200, 50);
  [nested updateWithRows:@[ row ]
               columnWidths:@[ @100, @100 ]
                 rowHeights:@[ @50 ]
                borderColor:UIColor.blackColor
                borderWidth:1
      horizontalCellPadding:5
        verticalCellPadding:5
               cornerRadius:0];
  UIEvent *touch = [ENRMTableTouchEvent new];
  CGPoint space = CGPointMake(5 + [@"A" sizeWithAttributes:@{NSFontAttributeName : font}].width * 1.5, 12);
  XCTAssertNotEqual([nested hitTest:space withEvent:touch], nested);
  XCTAssertEqual(nested.table.dynamicProps.activeSelectionGrid, nested);
  for (NSValue *value in @[
         [NSValue valueWithCGPoint:CGPointMake(1, 12)], [NSValue valueWithCGPoint:CGPointMake(85, 12)],
         [NSValue valueWithCGPoint:CGPointMake(12, 40)], [NSValue valueWithCGPoint:CGPointMake(130, 12)]
       ]) {
    XCTAssertEqual([nested hitTest:value.CGPointValue withEvent:touch], nested);
  }
  if (@available(iOS 16.0, *)) {
    auto config = [UIEditMenuConfiguration configurationWithIdentifier:nil sourcePoint:CGPointMake(130, 12)];
    UIEditMenuInteraction *interaction = [[UIEditMenuInteraction alloc] initWithDelegate:nested.table];
    UIMenu *menu = [nested.table editMenuInteraction:interaction menuForConfiguration:config suggestedActions:@[]];
    XCTAssertEqualObjects([menu.children valueForKey:@"title"], (@[ @"Copy", @"Copy as Markdown" ]));
    XCTAssertNil(nested.table.dynamicProps.activeSelectionGrid);
  }
  [nested hitTest:space withEvent:touch];
  XCTAssertEqual(outer.table.dynamicProps.activeSelectionGrid, nested);
  auto disabled = std::make_shared<facebook::react::EnrichedMarkdownProps>(*props);
  disabled->selectable = false;
  [document updateProps:disabled oldProps:props];
  [document finalizeUpdates:RNComponentViewUpdateMaskProps];
  XCTAssertNil(nested.table.dynamicProps.activeSelectionGrid);
  XCTAssertEqual([nested hitTest:space withEvent:touch], nested);
  XCTAssertTrue([outer isDescendantOfView:document]);
  XCTAssertTrue([nested isDescendantOfView:document]);
  XCTAssertEqualWithAccuracy(scroll.contentOffset.x, 24, 0.01);
  window.hidden = YES;
}
@end
