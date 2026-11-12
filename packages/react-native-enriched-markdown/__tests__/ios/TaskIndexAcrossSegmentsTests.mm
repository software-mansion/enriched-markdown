#import "../../ios/parser/ENRMMarkdownParser.h"
#import "../../ios/parser/MarkdownASTNode.h"
#import "../../ios/renderer/ListItemRenderer.h"
#import "../../ios/segments/ENRMBlockquoteContainerView.h"
#import "../../ios/segments/RenderedMarkdownSegment.h"
#import "../../ios/segments/SegmentRenderer.h"
#import "../../ios/styles/StyleConfig.h"
#import "../../ios/utils/ENRMAccessibilityLabels.h"
#import "../../ios/utils/ENRMTextRenderer.h"
#import "../../ios/utils/TaskListTapUtils.h"
#import "../../ios/views/EnrichedMarkdownInternalText.h"
#import <XCTest/XCTest.h>

static NSArray<ENRMRenderedSegment *> *ENRMRender(NSString *markdown)
{
  MarkdownASTNode *ast = [[[ENRMMarkdownParser alloc] init] parseMarkdown:markdown
                                                                    flags:[ENRMMd4cFlags defaultFlags]
                                                                    isGFM:YES];
  return ENRMRenderSegmentsFromAST(ast, [[StyleConfig alloc] init], YES, YES, 0, NSLineBreakStrategyStandard, NO, 0);
}

static void ENRMAddTaskIndicesInText(NSAttributedString *text, NSMutableArray<NSNumber *> *indices)
{
  NSMutableArray<NSNumber *> *own = [NSMutableArray array];
  [text enumerateAttribute:TaskIndexAttribute
                   inRange:NSMakeRange(0, text.length)
                   options:0
                usingBlock:^(NSNumber *value, NSRange range, BOOL *stop) {
                  if (value && ![own.lastObject isEqualToNumber:value]) {
                    [own addObject:value];
                  }
                }];
  [indices addObjectsFromArray:own];
}

static void ENRMAddTaskIndicesInViews(NSArray<UIView *> *views, NSMutableArray<NSNumber *> *indices)
{
  for (UIView *view in views) {
    if ([view isKindOfClass:[EnrichedMarkdownInternalText class]]) {
      ENRMAddTaskIndicesInText(((EnrichedMarkdownInternalText *)view).textView.attributedText, indices);
    } else if ([view isKindOfClass:[ENRMBlockquoteContainerView class]]) {
      ENRMAddTaskIndicesInViews(((ENRMBlockquoteContainerView *)view).segmentViews, indices);
    }
  }
}

// The task indices in document order. A quote's tasks are read from its view, which renders them.
static NSArray<NSNumber *> *ENRMTaskIndices(NSArray<ENRMRenderedSegment *> *segments)
{
  NSMutableArray<NSNumber *> *indices = [NSMutableArray array];
  for (ENRMRenderedSegment *segment in segments) {
    if (segment.textResult) {
      ENRMAddTaskIndicesInText(segment.textResult.attributedText, indices);
    } else if (segment.blockquoteSegment) {
      ENRMBlockquoteContainerView *quote =
          [[ENRMBlockquoteContainerView alloc] initWithConfig:[[StyleConfig alloc] init]];
      quote.accessibilityLabels = [ENRMAccessibilityLabels new];
      [quote applyBlockquoteNode:segment.blockquoteSegment.blockquoteNode
                 taskIndexOffset:segment.blockquoteSegment.taskIndexOffset];
      ENRMAddTaskIndicesInViews(quote.segmentViews, indices);
    }
  }
  return indices;
}

@interface ENRMTaskIndexAcrossSegmentsTests : XCTestCase
@end

@implementation ENRMTaskIndexAcrossSegmentsTests

- (void)testTasksAreNumberedInDocumentOrder
{
  NSString *markdown =
      @"- [ ] a\n"
      @"- [ ]not-a-task\n"
      @"- [ ] b\n"
      @"\n"
      @"| t |\n"
      @"|---|\n"
      @"| 1 |\n"
      @"\n"
      @"1. [ ] c\n"
      @"\n"
      @"```\n"
      @"code\n"
      @"```\n"
      @"\n"
      @"> - [ ] d\n"
      @">\n"
      @"> > - [ ] e\n"
      @"\n"
      @"- [ ] f\n";
  NSArray<NSString *> *tasks = @[ @"a", @"b", @"c", @"d", @"e", @"f" ];

  XCTAssertEqualObjects(ENRMTaskIndices(ENRMRender(markdown)), (@[ @0, @1, @2, @3, @4, @5 ]));
  // Toggling task N rewrites the Nth task of the markdown.
  for (NSUInteger index = 0; index < tasks.count; index++) {
    NSString *toggled = toggleTaskListItemAtIndex(markdown, index, YES);
    XCTAssertTrue([toggled containsString:[@"[x] " stringByAppendingString:tasks[index]]], @"task %@", tasks[index]);
  }
}

- (void)testTasksAreRenumberedWhenAnEarlierTaskIsAdded
{
  NSString *rest =
      @"| t |\n"
      @"|---|\n"
      @"| 1 |\n"
      @"\n"
      @"no tasks\n"
      @"\n"
      @"> - [ ] b\n"
      @"\n"
      @"- [ ] c\n";
  NSArray<ENRMRenderedSegment *> *before = ENRMRender([@"- [ ] a\n\n" stringByAppendingString:rest]);
  NSArray<ENRMRenderedSegment *> *after = ENRMRender([@"- [ ] a\n- [ ] new\n\n" stringByAppendingString:rest]);

  XCTAssertEqual(before[2].signature, after[2].signature);
  XCTAssertNotEqual(before[3].signature, after[3].signature);
  XCTAssertNotEqual(before[4].signature, after[4].signature);
  XCTAssertEqualObjects(ENRMTaskIndices(after), (@[ @0, @1, @2, @3 ]));
}

@end
