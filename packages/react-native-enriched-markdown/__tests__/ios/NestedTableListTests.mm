#import "../../ios/EnrichedMarkdown.h"
#import "../../ios/segments/ENRMCodeBlockContainerView.h"
#import "../../ios/utils/ENRMAccessibilityLabels.h"
#import "../../ios/utils/ENRMAsyncRenderCoordinator.h"
#import "../../ios/utils/ENRMFeatureFlags.h"
#if ENRICHED_MARKDOWN_MATH
#import "../../ios/segments/ENRMMathContainerView.h"
#endif
#import "../../ios/parser/MarkdownASTNode.h"
#import "../../ios/renderer/ListItemRenderer.h"
#import "../../ios/renderer/RenderContext.h"
#import "../../ios/segments/ENRMListContainerView.h"
#import "../../ios/segments/RenderedMarkdownSegment.h"
#import "../../ios/segments/SegmentRenderer.h"
#import "../../ios/segments/TableContainerView.h"
#import "../../ios/styles/StyleConfig.h"
#import "../../ios/utils/ENRMTextRenderer.h"
#import "../../ios/views/EnrichedMarkdownInternalText.h"
#import <XCTest/XCTest.h>

static MarkdownASTNode *ENRMTestNode(MarkdownNodeType type, NSArray<MarkdownASTNode *> *children)
{
  MarkdownASTNode *node = [[MarkdownASTNode alloc] initWithType:type];
  [node.children addObjectsFromArray:children];
  return node;
}

static MarkdownASTNode *ENRMTestParagraph(NSString *text)
{
  MarkdownASTNode *node = ENRMTestNode(MarkdownNodeTypeText, @[]);
  node.content = text;
  return ENRMTestNode(MarkdownNodeTypeParagraph, @[ node ]);
}

static MarkdownASTNode *ENRMTestTable(void)
{
  MarkdownASTNode *header = ENRMTestNode(MarkdownNodeTypeTableHeaderCell, @[ ENRMTestParagraph(@"Service") ]);
  MarkdownASTNode *cell = ENRMTestNode(MarkdownNodeTypeTableCell, @[ ENRMTestParagraph(@"API") ]);
  return ENRMTestNode(MarkdownNodeTypeTable, @[
    ENRMTestNode(MarkdownNodeTypeTableHead, @[ ENRMTestNode(MarkdownNodeTypeTableRow, @[ header ]) ]),
    ENRMTestNode(MarkdownNodeTypeTableBody, @[ ENRMTestNode(MarkdownNodeTypeTableRow, @[ cell ]) ])
  ]);
}

static void ENRMCollectViews(UIView *view, Class type, NSMutableArray *result)
{
  if ([view isKindOfClass:type])
    [result addObject:view];
  for (UIView *child in view.subviews)
    ENRMCollectViews(child, type, result);
}

@interface ENRMListContainerView (ENRMListClipboardTesting)
- (void)copyPlainTextToPasteboard;
@end

@interface EnrichedMarkdown (ENRMTaskActivationTesting)
- (void)renderMarkdownContent:(NSString *)markdown;
- (void)emitTaskListItemPress:(NSInteger)index checked:(BOOL)checked text:(NSString *)text;
@end

@interface ENRMTaskEventsDocument : EnrichedMarkdown
@property (nonatomic, strong) NSMutableArray<NSNumber *> *taskStates;
@end
@implementation ENRMTaskEventsDocument
- (void)emitTaskListItemPress:(NSInteger)index checked:(BOOL)checked text:(NSString *)text
{
  [self.taskStates addObject:@(checked)];
}
@end

@interface ENRMNestedTableListTests : XCTestCase
@end

@interface ENRMContainerNodeView (ENRMListBaselineTesting)
- (CGFloat)markerBaseline;
@end

@implementation ENRMNestedTableListTests {
  ENRMTaskEventsDocument *_taskDocument;
  ENRMAsyncRenderCoordinator *_taskCoordinator;
  dispatch_semaphore_t _releaseTaskRender;
}

- (void)tearDown
{
  if (_taskCoordinator) {
    [_taskCoordinator invalidate];
    dispatch_semaphore_signal(_releaseTaskRender);
    XCTestExpectation *drained = [self expectationWithDescription:@"task renders drained"];
    [_taskCoordinator scheduleRender:^BOOL { return YES; } apply:^{ [drained fulfill]; }];
    [self waitForExpectations:@[ drained ] timeout:5];
  }
  [super tearDown];
}

- (UIView *)taskTargetWithMarkdown:(NSString *)markdown
{
  _taskDocument = [[ENRMTaskEventsDocument alloc] initWithFrame:CGRectMake(0, 0, 320, 0)];
  _taskDocument.config = [StyleConfig new];
  _taskDocument.taskStates = [NSMutableArray array];
  [_taskDocument setValue:@YES forKey:@"enableTaskListItemToggle"];
  [_taskDocument renderMarkdownSynchronously:markdown];
  NSMutableArray<ENRMListContainerView *> *lists = [NSMutableArray array];
  ENRMCollectViews(_taskDocument, [ENRMListContainerView class], lists);
  lists.firstObject.dynamicProps.enableTaskListItemToggle = YES;
  NSMutableArray<UIView *> *targets = [NSMutableArray array];
  ENRMCollectViews(_taskDocument, NSClassFromString(@"ENRMListTaskTarget"), targets);
  XCTAssertEqual(targets.count, 1u);
  _taskCoordinator = [_taskDocument valueForKey:@"renderCoordinator"];
  _taskCoordinator.blockAsyncRender = NO;
  _releaseTaskRender = dispatch_semaphore_create(0);
  dispatch_semaphore_t started = dispatch_semaphore_create(0);
  dispatch_semaphore_t release = _releaseTaskRender;
  [_taskCoordinator
      scheduleRender:^BOOL {
        dispatch_semaphore_signal(started);
        dispatch_semaphore_wait(release, DISPATCH_TIME_FOREVER);
        return YES;
      }
               apply:^{}];
  XCTAssertEqual(dispatch_semaphore_wait(started, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)), 0L);
  return targets.firstObject;
}

- (void)testPendingTaskInsertionDoesNotToggleAnEarlierTask
{
  NSString *markdown = @"- [ ] A\n\n  | value |\n  |---|\n  | 1 |\n";
  UIView *target = [self taskTargetWithMarkdown:markdown];
  NSString *pending = [@"- [ ] B\n\n" stringByAppendingString:markdown];
  [_taskDocument renderMarkdownContent:pending];
  [target accessibilityActivate];
  XCTAssertEqualObjects([_taskDocument valueForKey:@"cachedMarkdown"], pending);
  XCTAssertEqual(_taskDocument.taskStates.count, 0u);
}

- (void)testTwoTaskActivationsBeforeRenderingRestoreTheUncheckedState
{
  NSString *markdown = @"- [ ] A\n\n  | value |\n  |---|\n  | 1 |\n";
  UIView *target = [self taskTargetWithMarkdown:markdown];
  [target accessibilityActivate];
  [target accessibilityActivate];
  XCTAssertEqualObjects(_taskDocument.taskStates, (@[ @YES, @NO ]));
  XCTAssertEqualObjects([_taskDocument valueForKey:@"cachedMarkdown"], markdown);
  XCTAssertFalse((target.accessibilityTraits & UIAccessibilityTraitSelected) != 0);
}

- (void)testTaskActivationDuringAnAppendOnlyUpdateKeepsTheAppendedContent
{
  NSString *markdown = @"- [ ] A\n\n  | value |\n  |---|\n  | 1 |\n";
  UIView *target = [self taskTargetWithMarkdown:markdown];
  NSString *pending = [markdown stringByAppendingString:@"\nTail"];
  [_taskDocument renderMarkdownContent:pending];
  [target accessibilityActivate];
  XCTAssertEqualObjects(_taskDocument.taskStates, (@[ @YES ]));
  XCTAssertEqualObjects([_taskDocument valueForKey:@"cachedMarkdown"],
                        [pending stringByReplacingOccurrencesOfString:@"[ ] A" withString:@"[x] A"]);
}

- (void)testListForwardsChangedAccessibilityLabelsToCodeAndMath
{
  MarkdownASTNode *code = ENRMTestNode(MarkdownNodeTypeCodeBlock, @[]);
  code.content = @"const x = 1;";
  NSMutableArray *children = [NSMutableArray arrayWithArray:@[ ENRMTestTable(), code ]];
#if ENRICHED_MARKDOWN_MATH
  MarkdownASTNode *math = ENRMTestNode(MarkdownNodeTypeLatexMathDisplay, @[]);
  math.content = @"x";
  [children addObject:math];
#endif
  MarkdownASTNode *document = ENRMTestNode(
      MarkdownNodeTypeDocument,
      @[ ENRMTestNode(MarkdownNodeTypeUnorderedList, @[ ENRMTestNode(MarkdownNodeTypeListItem, children) ]) ]);
  StyleConfig *config = [StyleConfig new];
  ENRMRenderedSegment *segment =
      ENRMRenderSegmentsFromAST(document, config, NO, YES, 0, NSLineBreakStrategyNone, NO, 0).firstObject;
  ENRMListContainerView *list = [[ENRMListContainerView alloc] initWithConfig:config];
  list.accessibilityLabels = [ENRMAccessibilityLabels new];
  [list applyListSegment:segment.listSegment];
  ENRMAccessibilityLabels *labels = [ENRMAccessibilityLabels new];
  labels.codeBlockWrap = @"Wrap updated";
  labels.mathEquation = @"Equation updated: {latex}";
  NSMutableArray<ENRMCodeBlockContainerView *> *codes = [NSMutableArray array];
  ENRMCollectViews(list, [ENRMCodeBlockContainerView class], codes);
  XCTAssertEqual(codes.count, 1u);
  codes.firstObject.showsWrapButton = YES;
  list.accessibilityLabels = labels;
  XCTAssertEqual(codes.firstObject.accessibilityLabels, labels);
  XCTAssertTrue([[codes.firstObject.accessibilityCustomActions valueForKey:@"name"] containsObject:@"Wrap updated"]);
#if ENRICHED_MARKDOWN_MATH
  NSMutableArray<ENRMMathContainerView *> *maths = [NSMutableArray array];
  ENRMCollectViews(list, [ENRMMathContainerView class], maths);
  XCTAssertEqual(maths.count, 1u);
  XCTAssertEqual(maths.firstObject.accessibilityLabels, labels);
  XCTAssertEqualObjects(maths.firstObject.accessibilityLabel, @"Equation updated: x");
#endif
}

- (void)testNestedTableKeepsItsNativeSegmentAndListTextMetadata
{
  MarkdownASTNode *table = ENRMTestNode(MarkdownNodeTypeTable, @[]);
  MarkdownASTNode *item =
      ENRMTestNode(MarkdownNodeTypeListItem, @[ ENRMTestParagraph(@"Before"), table, ENRMTestParagraph(@"After") ]);
  MarkdownASTNode *list = ENRMTestNode(MarkdownNodeTypeOrderedList, @[ item ]);
  list.attributes[@"start"] = @"7";
  MarkdownASTNode *document = ENRMTestNode(MarkdownNodeTypeDocument, @[ list ]);
  StyleConfig *config = [StyleConfig new];
  NSArray<ENRMRenderedSegment *> *root =
      ENRMRenderSegmentsFromAST(document, config, NO, YES, 0, NSLineBreakStrategyNone, NO, 0);
  XCTAssertEqual(root.count, 1u);
  XCTAssertEqual(root.firstObject.kind, ENRMSegmentKindList);
  ENRMListMarkerDescriptor *marker = [ENRMListMarkerDescriptor new];
  marker.listType = ListTypeOrdered;
  marker.number = 7;
  NSArray<ENRMRenderedSegment *> *body =
      ENRMRenderListItemSegments(item, config, root.firstObject.listSegment, marker, YES, NSLineBreakStrategyNone);
  XCTAssertEqual(body.count, 3u);
  XCTAssertEqual(body[1].kind, ENRMSegmentKindTable);
  XCTAssertEqual(body[1].tableSegment.tableNode, table);
  for (ENRMRenderedSegment *segment in @[ body[0], body[2] ]) {
    NSAttributedString *text = segment.textResult.attributedText;
    XCTAssertEqualObjects([text attribute:ListItemNumberAttribute atIndex:0 effectiveRange:NULL], @7);
    XCTAssertNil([text attribute:ListItemMarkerStartAttribute atIndex:0 effectiveRange:NULL]);
    XCTAssertEqual(segment.textResult.context.listItemRanges.count, 1u);
  }
}

- (void)testOrdinaryListsKeepTheirTextRenderer
{
  MarkdownASTNode *item = ENRMTestNode(MarkdownNodeTypeListItem, @[ ENRMTestParagraph(@"Plain item") ]);
  MarkdownASTNode *list = ENRMTestNode(MarkdownNodeTypeUnorderedList, @[ item ]);
  MarkdownASTNode *document = ENRMTestNode(MarkdownNodeTypeDocument, @[ list ]);
  NSArray<ENRMRenderedSegment *> *segments =
      ENRMRenderSegmentsFromAST(document, [StyleConfig new], NO, YES, 0, NSLineBreakStrategyNone, NO, 0);
  XCTAssertEqual(segments.firstObject.kind, ENRMSegmentKindText);
}

- (void)testListBodyUsesOneFontScale
{
  StyleConfig *config = [StyleConfig new];
  [config setListStyleFontSize:18];
  [config setListStyleLineHeight:26];
  [config setFontScaleMultiplier:1.5];
  StyleConfig *body = [config configForListItemBody];
  XCTAssertEqualWithAccuracy(body.paragraphFontSize, config.listStyleFontSize, 0.01);
  XCTAssertEqualWithAccuracy(body.paragraphLineHeight, config.listStyleLineHeight, 0.01);
}

- (void)testNativeLayoutAndViewFreeHeightAgreeForNestedTableLists
{
  StyleConfig *config = [StyleConfig new];
  [config setListStyleFontSize:18];
  [config setListStyleMarginLeft:32];
  [config setListStyleItemSpacing:8];
  [config setTableFontSize:16];
  [config setTableCellPaddingVertical:12];
  [config setTableCellPaddingHorizontal:12];
  [config setTableBorderWidth:1];
  for (NSInteger scenario = 0; scenario < 12; scenario++) {
    NSInteger shape = scenario % 4;
    BOOL rtl = scenario >= 8;
    [config setFontScaleMultiplier:scenario >= 4 ? 1.7 : 1];
    MarkdownASTNode *table = ENRMTestTable();
    MarkdownASTNode *block = shape == 1   ? ENRMTestNode(MarkdownNodeTypeUnorderedList,
                                                         @[ ENRMTestNode(MarkdownNodeTypeListItem, @[ table ]) ])
                             : shape == 2 ? ENRMTestNode(MarkdownNodeTypeBlockquote, @[ table ])
                                          : table;
    NSArray *children = shape == 3
                            ? @[ block, ENRMTestParagraph(@"After") ]
                            : @[ ENRMTestParagraph(rtl ? @"أصل" : @"Before"), block, ENRMTestParagraph(@"After") ];
    MarkdownASTNode *list = ENRMTestNode(MarkdownNodeTypeOrderedList, @[
      ENRMTestNode(MarkdownNodeTypeListItem, children),
      ENRMTestNode(MarkdownNodeTypeListItem, @[ ENRMTestParagraph(@"Next") ])
    ]);
    list.attributes[@"start"] = @"999";
    ENRMListSegment *segment = ENRMRenderSegmentsFromAST(ENRMTestNode(MarkdownNodeTypeDocument, @[ list ]), config, NO,
                                                         YES, 0, NSLineBreakStrategyNone, NO, 0)
                                   .firstObject.listSegment;
    ENRMListContainerView *view = [[ENRMListContainerView alloc] initWithConfig:config];
    [view applyListSegment:segment];
    ENRMContainerNodeView *bodyView = (ENRMContainerNodeView *)view.segmentViews.firstObject;
    XCTAssertNotNil(bodyView.segmentViewRegistry);
    XCTAssertGreaterThan(bodyView.segmentViews.count, 0u, @"body nodes %@", list.children.firstObject.children);
    CGFloat height = [view measureHeight:360];
    CGFloat measured = [ENRMListContainerView measureListSegment:segment
                                                          config:config
                                                           width:360
                                                pointScaleFactor:UIScreen.mainScreen.scale
                                                allowFontScaling:YES
                                               lineBreakStrategy:NSLineBreakStrategyNone
                                                      wrapCursor:nil
                                                    slotMeasurer:nil
                                                          origin:CGPointZero];
    XCTAssertGreaterThan(height, 0);
    XCTAssertEqualWithAccuracy(height, measured, 1, @"shape %ld", (long)shape);
    view.frame = CGRectMake(0, 0, 360, height);
    [view layoutIfNeeded];
    NSMutableArray *tables = [NSMutableArray array];
    ENRMCollectViews(view, [TableContainerView class], tables);
    XCTAssertEqual(tables.count, 1u);
    XCTAssertGreaterThan(((UIView *)tables.firstObject).bounds.size.height, 0);
    ENRMContainerNodeView *first = (ENRMContainerNodeView *)view.segmentViews.firstObject;
    XCTAssertGreaterThan(rtl && shape != 3 ? first.contentInsets.right : first.contentInsets.left, 0);
    [view applyListSegment:segment];
    XCTAssertEqual(view.segmentViews.firstObject, first);
  }
}

- (void)testNativeTaskUsesGlobalIndexAndLiveToggleGate
{
  StyleConfig *config = [StyleConfig new];
  MarkdownASTNode *item = ENRMTestNode(MarkdownNodeTypeListItem, @[ ENRMTestTable(), ENRMTestParagraph(@"Details") ]);
  item.attributes[@"isTask"] = @"true";
  ENRMListSegment *segment = [ENRMListSegment new];
  segment.node = ENRMTestNode(MarkdownNodeTypeUnorderedList, @[ item ]);
  segment.taskIndexOffset = 3;
  ENRMListContainerView *view = [[ENRMListContainerView alloc] initWithConfig:config];
  __block NSInteger calledIndex = -1;
  __block BOOL checked = NO;
  view.onTaskListItemPress = ^(NSInteger index, BOOL state, NSString *text) {
    calledIndex = index;
    checked = state;
  };
  [view applyListSegment:segment];
  UIView *target = ((ENRMContainerNodeView *)view.segmentViews.firstObject).accessibilityElements.firstObject;
  view.dynamicProps.enableTaskListItemToggle = NO;
  XCTAssertTrue((target.accessibilityTraits & UIAccessibilityTraitNotEnabled) != 0);
  [target accessibilityActivate];
  XCTAssertEqual(calledIndex, -1);
  view.dynamicProps.enableTaskListItemToggle = YES;
  XCTAssertFalse((target.accessibilityTraits & UIAccessibilityTraitNotEnabled) != 0);
  [target accessibilityActivate];
  XCTAssertEqual(calledIndex, 3);
  XCTAssertTrue(checked);
}

- (void)testTaskOffsetIncludesEarlierTextSegmentsAndNestedLists
{
  MarkdownASTNode *before = ENRMTestNode(MarkdownNodeTypeListItem, @[ ENRMTestParagraph(@"Earlier task") ]);
  before.attributes[@"isTask"] = @"true";
  MarkdownASTNode *task = ENRMTestNode(MarkdownNodeTypeListItem, @[ ENRMTestTable() ]);
  task.attributes[@"isTask"] = @"true";
  MarkdownASTNode *list = ENRMTestNode(MarkdownNodeTypeOrderedList, @[ task ]);
  MarkdownASTNode *document =
      ENRMTestNode(MarkdownNodeTypeDocument, @[ ENRMTestNode(MarkdownNodeTypeUnorderedList, @[ before ]), list ]);
  NSArray<ENRMRenderedSegment *> *segments =
      ENRMRenderSegmentsFromAST(document, [StyleConfig new], NO, YES, 0, NSLineBreakStrategyNone, NO, 0);
  XCTAssertEqual(segments.count, 2u);
  XCTAssertEqual(segments[1].listSegment.taskIndexOffset, 1);
}

- (void)testNestedLeavesUseHostCreationAndUpdates
{
  StyleConfig *config = [StyleConfig new];
  MarkdownASTNode *paragraph = ENRMTestParagraph(@"Before");
  ENRMListSegment *segment = [ENRMListSegment new];
  segment.node = ENRMTestNode(MarkdownNodeTypeUnorderedList,
                              @[ ENRMTestNode(MarkdownNodeTypeListItem, @[ paragraph, ENRMTestTable() ]) ]);
  ENRMListContainerView *view = [[ENRMListContainerView alloc] initWithConfig:config];
  __block NSInteger created = 0;
  __block NSInteger updated = 0;
  view.createLeafView = ^UIView *(ENRMRenderedSegment *part) {
    if (part.kind != ENRMSegmentKindText)
      return nil;
    created++;
    EnrichedMarkdownInternalText *text = [[EnrichedMarkdownInternalText alloc] initWithConfig:config];
    text.textView.selectable = NO;
    [text applyAttributedText:part.textResult.attributedText context:part.textResult.context];
    return text;
  };
  view.updateLeafView = ^BOOL(UIView *child, ENRMRenderedSegment *part) {
    if (part.kind != ENRMSegmentKindText)
      return NO;
    updated++;
    [(EnrichedMarkdownInternalText *)child applyAttributedText:part.textResult.attributedText
                                                       context:part.textResult.context];
    return YES;
  };
  [view applyListSegment:segment];
  XCTAssertEqual(created, 1);
  EnrichedMarkdownInternalText *text =
      (EnrichedMarkdownInternalText *)((ENRMContainerNodeView *)view.segmentViews.firstObject).segmentViews.firstObject;
  XCTAssertFalse(text.textView.selectable);
  segment.node =
      ENRMTestNode(MarkdownNodeTypeUnorderedList,
                   @[ ENRMTestNode(MarkdownNodeTypeListItem, @[ ENRMTestParagraph(@"Updated"), ENRMTestTable() ]) ]);
  [view applyListSegment:segment];
  XCTAssertEqual(updated, 1);
  XCTAssertEqualObjects(text.textView.text, @"Updated");
}

- (void)testAttachmentFirstItemKeepsTheTextBaselineWhenASiblingContainsATable
{
  StyleConfig *config = [StyleConfig new];
  ENRMListSegment *segment = [ENRMListSegment new];
  segment.node = ENRMTestNode(MarkdownNodeTypeUnorderedList, @[
    ENRMTestNode(MarkdownNodeTypeListItem, @[ ENRMTestParagraph(@"Attachment") ]),
    ENRMTestNode(MarkdownNodeTypeListItem, @[ ENRMTestTable() ])
  ]);
  ENRMListContainerView *view = [[ENRMListContainerView alloc] initWithConfig:config];
  NSTextAttachment *attachment = [NSTextAttachment new];
  attachment.bounds = CGRectMake(0, -12, 20, 32);
  view.createLeafView = ^UIView *(ENRMRenderedSegment *part) {
    if (part.kind != ENRMSegmentKindText)
      return nil;
    EnrichedMarkdownInternalText *text = [[EnrichedMarkdownInternalText alloc] initWithConfig:config];
    NSMutableAttributedString *value = [[NSAttributedString attributedStringWithAttachment:attachment] mutableCopy];
    [value addAttribute:NSFontAttributeName value:config.listStyleFont range:NSMakeRange(0, value.length)];
    [text applyAttributedText:value context:part.textResult.context];
    return text;
  };
  [view applyListSegment:segment];
  view.frame = CGRectMake(0, 0, 320, [view measureHeight:320]);
  [view layoutIfNeeded];
  ENRMContainerNodeView *item = (ENRMContainerNodeView *)view.segmentViews.firstObject;
  [item layoutIfNeeded];
  EnrichedMarkdownInternalText *leaf = (EnrichedMarkdownInternalText *)item.segmentViews.firstObject;
  UITextView *text = leaf.textView;
  [text.layoutManager ensureLayoutForTextContainer:text.textContainer];
  CGRect line = [text.layoutManager lineFragmentRectForGlyphAtIndex:0 effectiveRange:NULL];
  CGPoint glyph = [text.layoutManager locationForGlyphAtIndex:0];
  CGFloat expected =
      leaf.frame.origin.y + text.frame.origin.y + text.textContainerInset.top + line.origin.y + glyph.y - 12;
  XCTAssertEqualWithAccuracy([item markerBaseline], expected, 0.01);
}

- (void)testExplicitWritingDirectionControlsNativeMarkerAndBody
{
  StyleConfig *config = [StyleConfig new];
  [config setListStyleFontSize:18];
  MarkdownASTNode *list =
      ENRMTestNode(MarkdownNodeTypeOrderedList,
                   @[ ENRMTestNode(MarkdownNodeTypeListItem, @[ ENRMTestParagraph(@"English"), ENRMTestTable() ]) ]);
  NSArray *rendered = ENRMRenderSegmentsFromAST(ENRMTestNode(MarkdownNodeTypeDocument, @[ list ]), config, NO, YES, 0,
                                                NSLineBreakStrategyNone, NO, 0);
  ENRMApplySegmentWritingDirection(rendered, ENRMWritingDirectionModeRTL, NSWritingDirectionLeftToRight);
  ENRMListContainerView *view = [[ENRMListContainerView alloc] initWithConfig:config];
  [view applyListSegment:((ENRMRenderedSegment *)rendered.firstObject).listSegment];
  ENRMContainerNodeView *item = (ENRMContainerNodeView *)view.segmentViews.firstObject;
  XCTAssertGreaterThan(item.contentInsets.right, 0);
  XCTAssertEqual(item.contentInsets.left, 0);
  EnrichedMarkdownInternalText *text = (EnrichedMarkdownInternalText *)item.segmentViews.firstObject;
  NSParagraphStyle *style = [text.textView.attributedText attribute:NSParagraphStyleAttributeName
                                                            atIndex:0
                                                     effectiveRange:NULL];
  XCTAssertEqual(style.baseWritingDirection, NSWritingDirectionRightToLeft);
}

- (void)testListSignatureTracksDescendantImageSourceOverrides
{
  StyleConfig *config = [StyleConfig new];
  MarkdownASTNode *image = ENRMTestNode(MarkdownNodeTypeImage, @[]);
  image.attributes[@"imageOccurrenceId"] = @"image-1";
  MarkdownASTNode *document =
      ENRMTestNode(MarkdownNodeTypeDocument,
                   @[ ENRMTestNode(MarkdownNodeTypeUnorderedList,
                                   @[ ENRMTestNode(MarkdownNodeTypeListItem, @[ ENRMTestTable(), image ]) ]) ]);
  ENRMImageSourceOverride *source = [ENRMImageSourceOverride new];
  source.uri = @"https://example.com/first.png";
  source.headers = @{};
  [config setImageSourceOverrides:@{@"image-1" : source}];
  uint64_t first =
      ENRMRenderSegmentsFromAST(document, config, NO, YES, 0, NSLineBreakStrategyNone, NO, 0).firstObject.signature;
  source.uri = @"https://example.com/second.png";
  uint64_t second =
      ENRMRenderSegmentsFromAST(document, config, NO, YES, 0, NSLineBreakStrategyNone, NO, 0).firstObject.signature;
  XCTAssertNotEqual(first, second);
}

- (void)testQuoteSignatureTracksInheritedTaskOffsetAndCheckedState
{
  MarkdownASTNode *task = ENRMTestNode(MarkdownNodeTypeListItem, @[ ENRMTestParagraph(@"Quoted") ]);
  task.attributes[@"isTask"] = @"true";
  MarkdownASTNode *quote =
      ENRMTestNode(MarkdownNodeTypeBlockquote, @[ ENRMTestNode(MarkdownNodeTypeUnorderedList, @[ task ]) ]);
  MarkdownASTNode *item = ENRMTestNode(MarkdownNodeTypeListItem, @[ ENRMTestTable(), quote ]);
  ENRMListSegment *parent = [ENRMListSegment new];
  parent.node = ENRMTestNode(MarkdownNodeTypeUnorderedList, @[ item ]);
  ENRMListMarkerDescriptor *marker = [ENRMListMarkerDescriptor new];
  marker.isTask = YES;
  marker.taskIndex = 0;
  uint64_t first = ENRMRenderListItemSegments(item, [StyleConfig new], parent, marker, YES, NSLineBreakStrategyNone)
                       .lastObject.signature;
  marker.taskIndex = 1;
  uint64_t shifted = ENRMRenderListItemSegments(item, [StyleConfig new], parent, marker, YES, NSLineBreakStrategyNone)
                         .lastObject.signature;
  XCTAssertNotEqual(first, shifted);
  marker.isChecked = YES;
  uint64_t checked = ENRMRenderListItemSegments(item, [StyleConfig new], parent, marker, YES, NSLineBreakStrategyNone)
                         .lastObject.signature;
  XCTAssertNotEqual(shifted, checked);
}
- (void)testListCopyHonorsLiveCopyLinksAsSetting
{
  MarkdownASTNode *label = ENRMTestNode(MarkdownNodeTypeText, @[]);
  label.content = @"Docs";
  MarkdownASTNode *link = ENRMTestNode(MarkdownNodeTypeLink, @[ label ]);
  link.attributes[@"url"] = @"https://example.com/docs";
  MarkdownASTNode *item =
      ENRMTestNode(MarkdownNodeTypeListItem, @[ ENRMTestNode(MarkdownNodeTypeParagraph, @[ link ]), ENRMTestTable() ]);
  MarkdownASTNode *document =
      ENRMTestNode(MarkdownNodeTypeDocument, @[ ENRMTestNode(MarkdownNodeTypeUnorderedList, @[ item ]) ]);
  StyleConfig *config = [StyleConfig new];
  ENRMRenderedSegment *segment =
      ENRMRenderSegmentsFromAST(document, config, NO, YES, 0, NSLineBreakStrategyNone, NO, 0).firstObject;
  ENRMListContainerView *view = [[ENRMListContainerView alloc] initWithConfig:config];
  [view applyListSegment:segment.listSegment];
  UIPasteboard *pasteboard = UIPasteboard.generalPasteboard;
  NSArray *originalItems = pasteboard.items;
  @try {
    for (NSNumber *enabled in @[ @NO, @YES, @NO ]) {
      [config setCopyLinksAsMarkdown:enabled.boolValue];
      [view copyPlainTextToPasteboard];
      NSString *copied = pasteboard.string;
      XCTAssertTrue([copied containsString:@"Docs"]);
      XCTAssertEqual([copied containsString:@"[Docs](https://example.com/docs)"], enabled.boolValue);
    }
  } @finally {
    pasteboard.items = originalItems;
  }
}

@end
