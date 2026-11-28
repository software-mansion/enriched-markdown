#import "../../ios/EnrichedMarkdown.h"
#import "../../ios/parser/ENRMMarkdownParser.h"
#import "../../ios/parser/MarkdownASTNode.h"
#import "../../ios/segments/ENRMTableIOSGridView.h"
#import "../../ios/segments/TableContainerView.h"
#import "../../ios/utils/MarkdownExtractor.h"
#import "../../ios/utils/PasteboardUtils.h"
#import "../../ios/utils/RuntimeKeys.h"
#import <React/RCTConversions.h>
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

@interface TableContainerView (ENRMTableSelectionTestMenu) <UIEditMenuInteractionDelegate,
                                                            UIContextMenuInteractionDelegate>
@end

@interface ENRMTableIOSGridView (ENRMTableSelectionTestHit)
- (ENRMTableIOSItemHit *)itemAtPoint:(CGPoint)point allowsNearestLink:(BOOL)allowsNearestLink;
@end

@interface ENRMTestTableSelectionHost : NSObject <ENRMTableSelectionHost>
@end
@implementation ENRMTestTableSelectionHost
- (BOOL)tableSelectionEnabled
{
  return YES;
}
- (void)configureTableSelectionView:(ENRMTableCellTextView *)textView
{
}
@end

static ENRMTableIOSRowData *ENRMTestRow(NSArray<NSAttributedString *> *texts)
{
  ENRMTableIOSRowData *row = [ENRMTableIOSRowData new];
  row.cellTexts = texts;
  row.backgroundColor = UIColor.whiteColor;
  return row;
}

static void ENRMUpdateTestGrid(ENRMTableIOSGridView *grid, NSArray<ENRMTableIOSRowData *> *rows,
                               NSArray<NSNumber *> *widths, NSArray<NSNumber *> *heights)
{
  [grid updateWithRows:rows
               columnWidths:widths
                 rowHeights:heights
                borderColor:UIColor.blackColor
                borderWidth:1
      horizontalCellPadding:5
        verticalCellPadding:5
               cornerRadius:0];
}

static MarkdownASTNode *ENRMParseTable(NSString *markdown)
{
  return [[[ENRMMarkdownParser new] parseMarkdown:markdown flags:[ENRMMd4cFlags defaultFlags] isGFM:YES] children]
      .firstObject;
}

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
  props->enableBlockContextMenu = true;
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
  nested.frame = CGRectMake(0, 0, 200, 50);
  ENRMUpdateTestGrid(nested, @[ ENRMTestRow(@[ text, [[NSAttributedString alloc] initWithString:@""] ]) ],
                     @[ @100, @100 ], @[ @50 ]);
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
  ENRMTableCellTextView *editor = nested.selectionView;
  auto recolored = std::make_shared<facebook::react::EnrichedMarkdownProps>(*props);
  recolored->selectionColor = facebook::react::colorFromRGBA(255, 0, 0, 255);
  [document updateProps:recolored oldProps:props];
  [document finalizeUpdates:RNComponentViewUpdateMaskProps];
  XCTAssertEqual(nested.selectionView, editor);
  XCTAssertEqualObjects(editor.tintColor, RCTUIColorFromSharedColor(recolored->selectionColor));
  auto disabled = std::make_shared<facebook::react::EnrichedMarkdownProps>(*recolored);
  disabled->selectable = false;
  [document updateProps:disabled oldProps:recolored];
  [document finalizeUpdates:RNComponentViewUpdateMaskProps];
  XCTAssertNil(nested.table.dynamicProps.activeSelectionGrid);
  XCTAssertEqual([nested hitTest:space withEvent:touch], nested);
  XCTAssertTrue([outer isDescendantOfView:document]);
  XCTAssertTrue([nested isDescendantOfView:document]);
  XCTAssertEqualWithAccuracy(scroll.contentOffset.x, 24, 0.01);
  window.hidden = YES;
}

- (void)testStreamedSelectionUsesFinalWrappingAndShownAlignment
{
  UIFont *font = [UIFont monospacedSystemFontOfSize:16 weight:UIFontWeightRegular];
  TableContainerView *table = [[TableContainerView alloc] initWithConfig:[StyleConfig new]];
  ENRMTestTableSelectionHost *host = [ENRMTestTableSelectionHost new];
  table.dynamicProps.tableSelectionHost = host;
  ENRMTableIOSGridView *grid = ENRMFindTableGrid(table);
  grid.frame = CGRectMake(0, 0, 350, 140);
  NSAttributedString *empty = [[NSAttributedString alloc] initWithString:@""];
  UIEvent *touch = [ENRMTableTouchEvent new];

  NSMutableParagraphStyle *centered = [NSMutableParagraphStyle new];
  centered.alignment = NSTextAlignmentCenter;
  NSMutableParagraphStyle *trailing = [NSMutableParagraphStyle new];
  trailing.alignment = NSTextAlignmentRight;
  NSMutableParagraphStyle *rightToLeft = [NSMutableParagraphStyle new];
  rightToLeft.alignment = NSTextAlignmentNatural;
  rightToLeft.baseWritingDirection = NSWritingDirectionRightToLeft;
  NSMutableParagraphStyle *automatic = [rightToLeft mutableCopy];
  automatic.baseWritingDirection = NSWritingDirectionNatural;
  for (NSParagraphStyle *style in @[ centered, trailing, rightToLeft, automatic ]) {
    BOOL rtl = style.alignment == NSTextAlignmentNatural;
    NSString *string = rtl ? @"שלום עולם שלום\nסוף" : @"one two three ABC\nend";
    NSAttributedString *text = [[NSAttributedString alloc]
        initWithString:string
            attributes:@{NSFontAttributeName : font, NSParagraphStyleAttributeName : style}];
    ENRMTableIOSRowData *row = ENRMTestRow(@[ empty, text ]);
    ENRMUpdateTestGrid(grid, @[ row ], @[ @80, @180 ], @[ @85 ]);
    // The second cell starts at x=60, with a final text width of 170. The short final line
    // occupies the center or trailing part of that layout, even at a shown width of 95.
    [grid setShownColumnWidths:@[ @60, @95 ]];
    CGFloat anchor = style.alignment == NSTextAlignmentCenter ? 0.5 : (style == automatic ? 0 : 1);
    CGFloat textX = 65 - 85 * anchor;
    UITextView *reference = [[UITextView alloc] initWithFrame:CGRectMake(textX, 5, 170, 75) textContainer:nil];
    reference.scrollEnabled = NO;
    reference.textContainerInset = UIEdgeInsetsZero;
    reference.textContainer.lineFragmentPadding = 0;
    reference.attributedText = text;
    [reference.layoutManager ensureLayoutForTextContainer:reference.textContainer];
    NSUInteger lastGlyph = reference.layoutManager.numberOfGlyphs - 1;
    CGRect glyph = [reference.layoutManager boundingRectForGlyphRange:NSMakeRange(lastGlyph, 1)
                                                      inTextContainer:reference.textContainer];
    CGPoint point = CGPointMake(textX + CGRectGetMidX(glyph), 5 + CGRectGetMidY(glyph));
    XCTAssertTrue(point.x > 61 && point.x < 155, @"%@", NSStringFromCGPoint(point));
    XCTAssertGreaterThan(point.y, 24);
    XCTAssertNotEqual([grid hitTest:point withEvent:touch], grid);
    ENRMTableCellTextView *editor = grid.selectionView;
    XCTAssertNotNil(editor);
    XCTAssertEqualWithAccuracy(editor.frame.origin.x, textX, 0.01);
    XCTAssertEqualWithAccuracy(editor.textContainer.size.width, 170, 0.01);
    XCTAssertNotNil(editor.maskView);
    XCTAssertLessThan(editor.maskView.frame.size.width, editor.bounds.size.width);
    XCTAssertEqual([grid hitTest:CGPointMake(156, point.y) withEvent:touch], grid);

    NSRange selection = NSMakeRange(string.length - 3, 3);
    editor.selectedRange = selection;
    CGRect caret = [editor caretRectForPosition:editor.selectedTextRange.end];
    ENRMUpdateTestGrid(grid, @[ row, row ], @[ @80, @180 ], @[ @85, @55 ]);
    [grid setShownColumnWidths:@[ @70, @140 ]];
    XCTAssertEqual(grid.selectionView, editor);
    XCTAssertTrue(NSEqualRanges(editor.selectedRange, selection));
    XCTAssertEqualWithAccuracy(editor.frame.origin.x, 75 - 40 * anchor, 0.01);
    XCTAssertTrue(CGRectEqualToRect(caret, [editor caretRectForPosition:editor.selectedTextRange.end]));
    [grid setShownColumnWidths:nil];
    XCTAssertEqual(grid.selectionView, editor);
    XCTAssertNil(editor.maskView);
    XCTAssertEqualWithAccuracy(editor.frame.origin.x, 85, 0.01);
    [grid clearSelectionView];
  }
}

- (void)testNearestLinkHitAndPreviewCleanupOnChangedRows
{
  if (@available(iOS 17.0, *)) {
    UIWindow *window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 300, 240)];
    window.hidden = NO;
    TableContainerView *table = [[TableContainerView alloc] initWithConfig:[StyleConfig new]];
    table.frame = window.bounds;
    [window addSubview:table];
    ENRMLinkContextMenuItem *item = [ENRMLinkContextMenuItem new];
    item.text = @"Open";
    ENRMLinkContextMenuEntry *entry = [ENRMLinkContextMenuEntry new];
    entry.pattern = @"https://example.org";
    entry.items = @[ item ];
    table.dynamicProps.linkContextMenus = [ENRMLinkContextMenus new];
    table.dynamicProps.linkContextMenus.entries = @[ entry ];
    NSString *markdown = @"| Really wide column name |\n| --- |\n| [Docs](https://example.org) |";
    [table applyTableNode:ENRMParseTable(markdown)];
    ENRMTableIOSGridView *grid = ENRMFindTableGrid(table);
    UIContextMenuInteraction *interaction = grid.interactions.firstObject;
    CGFloat headerHeight = [table measureHeight:300] / 2;
    CGPoint nearest = CGPointMake(grid.bounds.size.width * 0.7, headerHeight * 1.5);
    ENRMTableIOSItemHit *hit = [grid itemAtPoint:nearest allowsNearestLink:YES];
    XCTAssertEqualObjects(hit.url, @"https://example.org");
    XCTAssertFalse(CGRectContainsPoint(hit.frame, nearest));
    XCTAssertNil([grid linkAtPoint:nearest]);
    XCTAssertFalse([grid ownsCellInteractionAtPoint:nearest]);
    XCTAssertNil([table contextMenuInteraction:interaction configurationForMenuAtLocation:nearest]);
    CGPoint link = CGPointMake(CGRectGetMidX(hit.frame), CGRectGetMidY(hit.frame));
    UIContextMenuConfiguration *menu = [table contextMenuInteraction:interaction configurationForMenuAtLocation:link];
    XCTAssertNotNil(menu);
    XCTAssertNotNil([table contextMenuInteraction:interaction previewForHighlightingMenuWithConfiguration:menu]);
    [table applyTableNode:ENRMParseTable(markdown)];
    XCTAssertNotNil([table contextMenuInteraction:interaction previewForDismissingMenuWithConfiguration:menu]);
    [table applyTableNode:ENRMParseTable([markdown stringByAppendingString:@"\n| New row |"])];
    XCTAssertNil([table contextMenuInteraction:interaction previewForDismissingMenuWithConfiguration:menu]);
    XCTAssertFalse([grid.subviews filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(
                                                                               UIView *view, NSDictionary *bindings) {
                                    return [view isKindOfClass:UIImageView.class];
                                  }]]
                       .count);
    window.hidden = YES;
  }
}

- (void)testAppendRebuildsImageAttachmentWithoutResettingSelection
{
  UIWindow *window = UIApplication.sharedApplication.delegate.window;
  StyleConfig *style = [StyleConfig new];
  [style setTableFontSize:16];
  [style setTableCellPaddingHorizontal:5];
  [style setTableCellPaddingVertical:5];
  [style setTableBorderWidth:0];
  TableContainerView *table = [[TableContainerView alloc] initWithConfig:style];
  table.frame = CGRectMake(0, 0, 300, 200);
  ENRMTestTableSelectionHost *host = [ENRMTestTableSelectionHost new];
  table.dynamicProps.tableSelectionHost = host;
  [window addSubview:table];
  NSString *header = @"| Cell |\n| --- |\n";
  [table applyTableNode:ENRMParseTable(header)];
  CGFloat headerHeight = [table measureHeight:300];
  NSString *markdown = [header stringByAppendingString:
                                   @"| Before "
                                   @"![Icon](data:image/"
                                   @"png;base64,"
                                   @"iVBORw0KGgoAAAANSUhEUgAAABAAAAAMCAIAAADkharWAAAAFUlEQVR4nGNIn7iNJMQwqmFUA3YEADu6Qp"
                                   @"Ba8tAUAAAAAElFTkSuQmCC) after |"];
  @try {
    [table applyTableNode:ENRMParseTable(markdown)];
    [table layoutIfNeeded];
    ENRMTableIOSGridView *grid = ENRMFindTableGrid(table);
    [grid hitTest:CGPointMake(12, headerHeight + 13) withEvent:[ENRMTableTouchEvent new]];
    ENRMTableCellTextView *editor = grid.selectionView;
    XCTAssertNotNil(editor);
    if (!editor)
      return;
    XCTAssertTrue([editor becomeFirstResponder]);
    editor.selectedRange = NSMakeRange(0, 6);
    NSUInteger imageIndex = [editor.attributedText.string rangeOfString:@"\uFFFC"].location;
    XCTAssertNotEqual(imageIndex, NSNotFound);
    if (imageIndex == NSNotFound)
      return;
    id oldAttachment = [editor.attributedText attribute:NSAttachmentAttributeName
                                                atIndex:imageIndex
                                         effectiveRange:NULL];
    XCTAssertNotNil(oldAttachment);
    NSString *appended = [markdown stringByAppendingString:@"\n| A new wider column entry |"];
    [table applyTableNode:ENRMParseTable(appended)];
    XCTAssertEqual(table.rowCount, 3u);
    XCTAssertEqual(grid.selectionView, editor);
    XCTAssertTrue(editor.isFirstResponder);
    XCTAssertTrue(NSEqualRanges(editor.selectedRange, NSMakeRange(0, 6)));
    id newAttachment = [editor.attributedText attribute:NSAttachmentAttributeName
                                                atIndex:imageIndex
                                         effectiveRange:NULL];
    XCTAssertNotNil(newAttachment);
    XCTAssertNotEqual(oldAttachment, newAttachment);
    XCTAssertEqual(objc_getAssociatedObject(editor.textContainer, kTextViewKey), editor);
    XCTAssertEqual(table.dynamicProps.tableSelectionHost, host);

    NSString *edited = [appended stringByReplacingOccurrencesOfString:@"| Before " withString:@"| **Before** "];
    [table applyTableNode:ENRMParseTable(edited)];
    XCTAssertNil(grid.selectionView);
    XCTAssertFalse(editor.isFirstResponder);
  } @finally {
    [table removeFromSuperview];
  }
}

- (void)testClippedGrabberLeavesNeighboringCellBlank
{
  UIWindow *window = UIApplication.sharedApplication.delegate.window;
  TableContainerView *table = [[TableContainerView alloc] initWithConfig:[StyleConfig new]];
  table.frame = CGRectMake(0, 0, 250, 90);
  ENRMTestTableSelectionHost *host = [ENRMTestTableSelectionHost new];
  table.dynamicProps.tableSelectionHost = host;
  [window addSubview:table];
  [table layoutIfNeeded];
  ENRMTableIOSGridView *grid = ENRMFindTableGrid(table);
  grid.frame = CGRectMake(0, 0, 250, 90);
  UIFont *font = [UIFont monospacedSystemFontOfSize:16 weight:UIFontWeightRegular];
  NSAttributedString *text = [[NSAttributedString alloc] initWithString:@"abcdefghij"
                                                             attributes:@{NSFontAttributeName : font}];
  NSAttributedString *blank = [[NSAttributedString alloc] initWithString:@""];
  ENRMUpdateTestGrid(grid, @[ ENRMTestRow(@[ text, blank ]) ], @[ @130, @90 ], @[ @55 ]);
  [grid setShownColumnWidths:@[ @48, @90 ]];
  UIEvent *touch = [ENRMTableTouchEvent new];
  [grid hitTest:CGPointMake(12, 14) withEvent:touch];
  ENRMTableCellTextView *editor = grid.selectionView;
  XCTAssertNotNil(editor);
  if (editor) {
    XCTAssertTrue([editor becomeFirstResponder]);
    editor.selectedRange = NSMakeRange(0, text.length);
    CGRect end = [editor caretRectForPosition:editor.selectedTextRange.end];
    CGPoint invisible = [grid convertPoint:CGPointMake(CGRectGetMidX(end), CGRectGetMaxY(end) + 5) fromView:editor];
    XCTAssertTrue(invisible.x > 48 && invisible.x < 138 && invisible.y < 55);
    XCTAssertEqual([grid hitTest:invisible withEvent:touch], grid);
    CGRect start = [editor caretRectForPosition:editor.selectedTextRange.start];
    CGPoint visible = [grid convertPoint:CGPointMake(CGRectGetMidX(start), CGRectGetMinY(start) - 5) fromView:editor];
    visible.y = MAX(1, visible.y);
    UIView *target = [grid hitTest:visible withEvent:touch];
    XCTAssertTrue(target == editor || [target isDescendantOfView:editor], @"%@", NSStringFromCGPoint(visible));
    [grid clearSelectionView];
  }
  XCTAssertEqual(table.dynamicProps.tableSelectionHost, host);
  [table removeFromSuperview];
}

- (void)testVerticallyClippedCaretLeavesBlankAreaAvailable
{
  UIWindow *window = UIApplication.sharedApplication.delegate.window;
  TableContainerView *table = [[TableContainerView alloc] initWithConfig:[StyleConfig new]];
  table.frame = CGRectMake(0, 0, 250, 90);
  ENRMTestTableSelectionHost *host = [ENRMTestTableSelectionHost new];
  table.dynamicProps.tableSelectionHost = host;
  [window addSubview:table];
  [table layoutIfNeeded];
  ENRMTableIOSGridView *grid = ENRMFindTableGrid(table);
  grid.frame = CGRectMake(0, 0, 250, 90);
  UIFont *font = [UIFont monospacedSystemFontOfSize:16 weight:UIFontWeightRegular];
  NSAttributedString *text = [[NSAttributedString alloc] initWithString:@"abcdefghij"
                                                             attributes:@{NSFontAttributeName : font}];
  [grid updateWithRows:@[ ENRMTestRow(@[ text ]) ]
               columnWidths:@[ @130 ]
                 rowHeights:@[ @55 ]
                borderColor:UIColor.blackColor
                borderWidth:26
      horizontalCellPadding:5
        verticalCellPadding:0
               cornerRadius:0];
  UIEvent *touch = [ENRMTableTouchEvent new];
  [grid hitTest:CGPointMake(38, 10) withEvent:touch];
  ENRMTableCellTextView *editor = grid.selectionView;
  XCTAssertNotNil(editor);
  if (editor) {
    XCTAssertTrue([editor becomeFirstResponder]);
    editor.selectedRange = NSMakeRange(3, 1);
    [grid setShownColumnWidths:@[ @70 ]];
    CGRect clip = editor.maskView.frame;
    CGRect caret = [editor caretRectForPosition:editor.selectedTextRange.end];
    CGPoint hold = CGPointMake(CGRectGetMidX(caret), CGRectGetMaxY(caret) + 5);
    XCTAssertNotNil(editor.maskView);
    XCTAssertGreaterThan(hold.x, CGRectGetMinX(clip));
    XCTAssertLessThan(hold.x, CGRectGetMaxX(clip));
    XCTAssertLessThan(hold.y, CGRectGetMinY(clip));
    XCTAssertEqual([grid hitTest:[grid convertPoint:hold fromView:editor] withEvent:touch], grid);
    [grid clearSelectionView];
  }
  XCTAssertEqual(table.dynamicProps.tableSelectionHost, host);
  [table removeFromSuperview];
}

static NSArray<NSString *> *ENRMMenuTitles(UIMenu *menu)
{
  NSMutableArray<NSString *> *titles = [NSMutableArray array];
  for (UIMenuElement *child in menu.children) {
    if ([child isKindOfClass:UIMenu.class])
      [titles addObjectsFromArray:ENRMMenuTitles((UIMenu *)child)];
    else
      [titles addObject:child.title];
  }
  return titles;
}

- (void)testCellSelectionKeepsLinksAndUsesConfiguredTableLabels
{
  UIWindow *window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 320, 400)];
  window.hidden = NO;
  EnrichedMarkdown *document = [[ENRMSynchronousTableTestDocument alloc] initWithFrame:window.bounds];
  [window addSubview:document];
  auto defaults = std::make_shared<const facebook::react::EnrichedMarkdownProps>();
  auto props = std::make_shared<facebook::react::EnrichedMarkdownProps>(*defaults);
  props->markdown = "| Service |\n| --- |\n| Restart [api](https://example.com/api) now |";
  props->isGFM = true;
  props->selectable = true;
  props->enableBlockContextMenu = true;
  props->selectionMenuConfig.copyLabel = "Copy";
  props->selectionMenuConfig.copyAsMarkdownLabel = "Copy as Markdown";
  props->selectionMenuConfig.copyAsMarkdown = true;
  props->selectionMenuConfig.copyTableLabel = "Tabelle kopieren";
  props->selectionMenuConfig.copyTableAsMarkdownLabel = "Tabelle als Markdown kopieren";
  [document updateProps:props oldProps:defaults];
  [document finalizeUpdates:RNComponentViewUpdateMaskProps];
  [document computeSegmentLayoutForWidth:320 applyFrames:YES];
  [document layoutIfNeeded];
  ENRMTableIOSGridView *grid = ENRMFindTableGrid(document);
  XCTAssertNotNil(grid);
  if (!grid)
    return;

  // The body row is the last one: scan upwards for its first plain-text point.
  CGPoint textPoint = CGPointZero;
  BOOL found = NO;
  for (CGFloat y = CGRectGetMaxY(grid.bounds) - 1; y > 0 && !found; y -= 2) {
    for (CGFloat x = 1; x < CGRectGetMaxX(grid.bounds) && !found; x += 2) {
      if ([grid itemAtPoint:CGPointMake(x, y) allowsNearestLink:NO].kind == ENRMTableIOSItemKindText) {
        textPoint = CGPointMake(x, y);
        found = YES;
      }
    }
  }
  XCTAssertTrue(found);
  [grid hitTest:textPoint withEvent:[ENRMTableTouchEvent new]];
  ENRMTableCellTextView *editor = grid.selectionView;
  XCTAssertNotNil(editor);
  if (!editor)
    return;

  // The grid draws cell text without NSLinkAttributeName; the editor keeps it so a copied selection keeps its link.
  NSAttributedString *text = editor.attributedText;
  NSRange link = [text.string rangeOfString:@"api"];
  XCTAssertNotEqual(link.location, NSNotFound);
  XCTAssertNotNil([text attribute:NSLinkAttributeName atIndex:link.location effectiveRange:NULL]);
  XCTAssertEqual(editor.linkTextAttributes.count, 0u);
  NSString *markdown = extractMarkdownFromAttributedString(text, NSMakeRange(0, text.length));
  XCTAssertTrue([markdown containsString:@"[api](https://example.com/api)"], @"%@", markdown);

  if (@available(iOS 16.0, *)) {
    UIMenu *menu = [(id<UITextViewDelegate>)document textView:editor
                                       editMenuForTextInRange:NSMakeRange(0, 7)
                                             suggestedActions:@[]];
    NSArray<NSString *> *titles = ENRMMenuTitles(menu);
    XCTAssertTrue([titles containsObject:@"Tabelle kopieren"], @"%@", titles);
    XCTAssertTrue([titles containsObject:@"Tabelle als Markdown kopieren"], @"%@", titles);
    XCTAssertFalse([titles containsObject:@"Copy Table"], @"%@", titles);

    // From iOS 16 the whole-table menu is an edit menu, so the context menu stays out of the way.
    UIContextMenuInteraction *interaction = [[UIContextMenuInteraction alloc] initWithDelegate:grid.table];
    CGPoint blank = CGPointMake(CGRectGetMaxX(grid.bounds) - 2, CGRectGetMaxY(grid.bounds) - 2);
    XCTAssertNil([grid.table contextMenuInteraction:interaction configurationForMenuAtLocation:blank]);
  }
  [grid clearSelectionView];
  window.hidden = YES;
}
@end
