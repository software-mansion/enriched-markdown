#import "../../ios/parser/ENRMMarkdownParser.h"
#import "../../ios/parser/MarkdownASTNode.h"
#import "../../ios/segments/ENRMBlockquoteContainerView.h"
#import "../../ios/styles/StyleConfig.h"
#import "../../ios/utils/ENRMAccessibilityLabels.h"
#import "../../ios/utils/ENRMTextRenderer.h"
#import "../../ios/utils/EditMenuUtils.h"
#import "../../ios/views/EnrichedMarkdownInternalText.h"
#import <XCTest/XCTest.h>

@interface ENRMSelectionCopyTests : XCTestCase
@end

@implementation ENRMSelectionCopyTests {
  NSMutableArray<NSDictionary *> *_copies;
}

- (void)setUp
{
  _copies = [NSMutableArray array];
  [UIPasteboard generalPasteboard].string = @"";
}

- (ENRMSelectionCopyHandler)recorder
{
  NSMutableArray<NSDictionary *> *copies = _copies;
  return ^(NSString *text, NSString *format, NSRange range) {
    [copies addObject:@{@"text" : text, @"format" : format, @"range" : [NSValue valueWithRange:range]}];
  };
}

static NSDictionary *ENRMCopy(NSString *text, NSString *format, NSRange range)
{
  return @{@"text" : text, @"format" : format, @"range" : [NSValue valueWithRange:range]};
}

static MarkdownASTNode *ENRMParse(NSString *markdown)
{
  return [[[ENRMMarkdownParser alloc] init] parseMarkdown:markdown flags:[ENRMMd4cFlags defaultFlags] isGFM:YES];
}

// "Value: 42", with "42" in bold.
- (EnrichedMarkdownInternalText *)segmentView
{
  StyleConfig *config = [[StyleConfig alloc] init];
  ENRMRenderResult *result =
      ENRMRenderASTNodes(ENRMParse(@"Value: **42**").children, config, NO, YES, 0, NSLineBreakStrategyStandard);
  EnrichedMarkdownInternalText *view = [[EnrichedMarkdownInternalText alloc] initWithConfig:config];
  [view applyAttributedText:result.attributedText context:result.context];
  return view;
}

static UIAction *ENRMFindAction(UIMenu *menu, NSString *identifier)
{
  for (UIMenuElement *element in menu.children) {
    if ([element isKindOfClass:[UIAction class]] && [((UIAction *)element).identifier isEqualToString:identifier]) {
      return (UIAction *)element;
    }
    if ([element isKindOfClass:[UIMenu class]]) {
      UIAction *nested = ENRMFindAction((UIMenu *)element, identifier);
      if (nested)
        return nested;
    }
  }
  return nil;
}

// UIKit has no public way to run an action; its handler is what a tap on the menu item calls.
static void ENRMPerform(UIAction *action)
{
  UIActionHandler handler = [action valueForKey:@"handler"];
  handler(action);
}

- (void)testCopyKeyCommandReportsPlainText
{
  EnrichedMarkdownInternalText *view = [self segmentView];
  view.onSelectionCopy = [self recorder];
  view.textView.selectedRange = NSMakeRange(7, 2);

  [view.textView copy:nil];

  XCTAssertEqualObjects(_copies, (@[ ENRMCopy(@"42", ENRMSelectionCopyFormatPlain, NSMakeRange(7, 2)) ]));
  XCTAssertEqualObjects([UIPasteboard generalPasteboard].string, @"42");
}

- (void)testCopyKeyCommandWithoutSelectionReportsNothing
{
  EnrichedMarkdownInternalText *view = [self segmentView];
  view.onSelectionCopy = [self recorder];
  view.textView.selectedRange = NSMakeRange(3, 0);

  [view.textView copy:nil];

  XCTAssertEqual(_copies.count, 0u);
}

- (void)testCopyKeyCommandInBlockquoteReportsThroughTheQuote
{
  StyleConfig *config = [[StyleConfig alloc] init];
  ENRMBlockquoteContainerView *quote = [[ENRMBlockquoteContainerView alloc] initWithConfig:config];
  quote.accessibilityLabels = [ENRMAccessibilityLabels new];
  quote.frame = CGRectMake(0, 0, 320, 1000);
  quote.onSelectionCopy = [self recorder];
  [quote applyBlockquoteNode:ENRMParse(@"> quoted text\n").children.firstObject];

  EnrichedMarkdownInternalText *text = nil;
  for (RCTUIView *segment in quote.segmentViews) {
    if ([segment isKindOfClass:[EnrichedMarkdownInternalText class]])
      text = (EnrichedMarkdownInternalText *)segment;
  }
  XCTAssertNotNil(text);
  text.textView.selectedRange = NSMakeRange(0, 6);

  [text.textView copy:nil];

  XCTAssertEqualObjects(_copies, (@[ ENRMCopy(@"quoted", ENRMSelectionCopyFormatPlain, NSMakeRange(0, 6)) ]));
}

- (void)testMenuItemsReportTheirFormat API_AVAILABLE(ios(16.0))
{
  EnrichedMarkdownInternalText *view = [self segmentView];
  NSAttributedString *text = view.textView.attributedText;
  NSRange range = NSMakeRange(7, 2);
  NSString *copyLabel = @"Copy";
  NSString *copyAsMarkdownLabel = @"Copy as Markdown";
  ENRMSelectionMenuConfig menuConfig = {
      .copyAsMarkdown = YES,
      .copyImageURL = YES,
      .copyLabel = copyLabel,
      .copyAsMarkdownLabel = copyAsMarkdownLabel,
  };
  UIMenu *menu =
      buildEditMenuForSelection(text, range, @"Value: **42**", view.config, @[], nil, menuConfig, [self recorder]);

  ENRMPerform(ENRMFindAction(menu, @"com.swmansion.enriched.markdown.copy"));
  XCTAssertEqualObjects([UIPasteboard generalPasteboard].string, @"42");
  ENRMPerform(ENRMFindAction(menu, @"com.swmansion.enriched.markdown.copyMarkdown"));
  XCTAssertEqualObjects([UIPasteboard generalPasteboard].string, @"**42**");

  XCTAssertEqualObjects(_copies, (@[
                          ENRMCopy(@"42", ENRMSelectionCopyFormatPlain, range),
                          ENRMCopy(@"**42**", ENRMSelectionCopyFormatMarkdown, range),
                        ]));
}

@end
