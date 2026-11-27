#import "../../ios/parser/ENRMMarkdownParser.h"
#import "../../ios/parser/MarkdownASTNode.h"
#import "../../ios/renderer/AttributedRenderer.h"
#import "../../ios/renderer/RenderContext.h"
#import "../../ios/segments/ENRMTableSpoilerCells.h"
#import "../../ios/styles/StyleConfig.h"
#import "../../ios/utils/ENRMSpoilerTapUtils.h"
#import "../../ios/utils/TaskListTapUtils.h"
#import <XCTest/XCTest.h>

static StyleConfig *ENRMSpoilerTestConfig(void)
{
  StyleConfig *config = [[StyleConfig alloc] init];
  [config setTaskListCheckedTextColor:[UIColor grayColor]];
  return config;
}

static NSMutableAttributedString *ENRMSpoilerTestRender(NSString *markdown, StyleConfig *config)
{
  MarkdownASTNode *document = [[[ENRMMarkdownParser alloc] init] parseMarkdown:markdown];
  return [[[AttributedRenderer alloc] initWithConfig:config] renderNodes:document.children
                                                                 context:[[RenderContext alloc] init]
                                                                   block:nil];
}

static CGFloat ENRMSpoilerTestAlpha(NSAttributedString *text, NSString *word)
{
  UIColor *color = [text attribute:NSForegroundColorAttributeName
                           atIndex:[text.string rangeOfString:word].location
                    effectiveRange:NULL];
  return CGColorGetAlpha(color.CGColor);
}

static NSMutableAttributedString *ENRMSpoilerTestCell(NSRange spoiler)
{
  NSDictionary *attributes =
      @{NSFontAttributeName : [UIFont systemFontOfSize:16], NSForegroundColorAttributeName : UIColor.blackColor};
  NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:@"secret suffix"
                                                                           attributes:attributes];
  [text addAttribute:SpoilerAttributeName value:@YES range:spoiler];
  ENRMConcealSpoilers(text);
  return text;
}

@interface ENRMSpoilerConcealTests : XCTestCase
@end

@implementation ENRMSpoilerConcealTests

- (void)testSpoilerInCheckedTaskRevealsInTheTaskColor
{
  NSMutableAttributedString *text = ENRMSpoilerTestRender(@"- [x] done ||secret|| tail", ENRMSpoilerTestConfig());
  NSRange secret = [text.string rangeOfString:@"secret"];
  NSRange done = [text.string rangeOfString:@"done"];
  XCTAssertEqual(ENRMSpoilerTestAlpha(text, @"secret"), 0.0);
  ENRMRevealSpoilerAtIndex(text, secret.location);
  XCTAssertEqualObjects([text attribute:NSForegroundColorAttributeName atIndex:secret.location effectiveRange:NULL],
                        [text attribute:NSForegroundColorAttributeName atIndex:done.location effectiveRange:NULL]);
}

- (void)testCheckingATaskKeepsItsSpoilerHidden
{
  StyleConfig *config = ENRMSpoilerTestConfig();
  UITextView *textView = [[UITextView alloc] init];
  ENRMSetAttributedText(textView, ENRMSpoilerTestRender(@"- [ ] open ||secret|| tail", config));
  XCTAssertTrue(updateTaskListItemCheckedState(textView, 0, YES, config));
  XCTAssertEqual(ENRMSpoilerTestAlpha(ENRMGetAttributedText(textView), @"secret"), 0.0);
}

- (void)testRevealedTableCellStaysRevealedOnlyWhileItsSpoilersAreUnchanged
{
  UIView *host = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 40)];
  ENRMTableSpoilerCells *cells = [[ENRMTableSpoilerCells alloc] initWithHost:host];
  cells.config = [[StyleConfig alloc] init];
  void (^show)(NSMutableAttributedString *) = ^(NSMutableAttributedString *text) {
    [cells syncWithTexts:@[ @[ text ] ] backgrounds:@[]];
    [cells layoutWithTextRect:^CGRect(NSUInteger row, NSUInteger column, CGRect *cellRect) {
      *cellRect = host.bounds;
      return host.bounds;
    }];
  };

  show(ENRMSpoilerTestCell(NSMakeRange(0, 6)));
  XCTAssertTrue([cells revealAtPoint:CGPointMake(4, 10)]);

  NSMutableAttributedString *same = ENRMSpoilerTestCell(NSMakeRange(0, 6));
  show(same);
  XCTAssertGreaterThan(ENRMSpoilerTestAlpha(same, @"secret"), 0.0);

  NSMutableAttributedString *wider = ENRMSpoilerTestCell(NSMakeRange(0, 13));
  show(wider);
  XCTAssertEqual(ENRMSpoilerTestAlpha(wider, @"secret"), 0.0);
}

@end
