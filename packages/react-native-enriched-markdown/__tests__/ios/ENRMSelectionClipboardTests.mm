#import "../../ios/styles/StyleConfig.h"
#import "../../ios/utils/PasteboardUtils.h"
#import <UIKit/UIPasteboard.h>
#import <XCTest/XCTest.h>

@interface ENRMSelectionClipboardTests : XCTestCase
@property (nonatomic, copy) NSArray *originalItems;
@end
@implementation ENRMSelectionClipboardTests
- (void)setUp
{
  [super setUp];
  self.originalItems = UIPasteboard.generalPasteboard.items;
}
- (void)tearDown
{
  UIPasteboard.generalPasteboard.items = self.originalItems;
  [super tearDown];
}
- (StyleConfig *)config
{
  StyleConfig *config = [[StyleConfig alloc] init];
  config.selectionClipboard = @{
    @"linkTextByUrl" : @{@"ref:one" : @"[Context](ref:one)"},
    @"htmlAttributes" : @{@"data-context" : @"a\"&<", @"bad name" : @"ignored"},
    @"mimeTypes" : @{@"com.example.context" : @"context-payload"}
  };
  return config;
}
- (NSAttributedString *)selection
{
  NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:@"before Context after"];
  [text addAttribute:NSLinkAttributeName value:@"ref:one" range:NSMakeRange(7, 7)];
  return text;
}
- (void)testCopyReplacesConfiguredLinkAndAddsEscapedMetadata
{
  copyAttributedStringToPasteboard([self selection], nil, [self config]);
  XCTAssertEqualObjects(UIPasteboard.generalPasteboard.string, @"before [Context](ref:one) after");
  NSString *html = [[NSString alloc] initWithData:[UIPasteboard.generalPasteboard dataForPasteboardType:kUTIHTML]
                                         encoding:NSUTF8StringEncoding];
  XCTAssertTrue([html containsString:@"data-context=\"a&quot;&amp;&lt;\""]);
  XCTAssertFalse([html containsString:@"bad name"]);
  XCTAssertEqualObjects([[NSString alloc]
                            initWithData:[UIPasteboard.generalPasteboard dataForPasteboardType:@"com.example.context"]
                                encoding:NSUTF8StringEncoding],
                        @"context-payload");
}
- (void)testSelectionOutsideConfiguredLinkKeepsOrdinaryClipboard
{
  copyAttributedStringToPasteboard([[self selection] attributedSubstringFromRange:NSMakeRange(0, 6)], nil,
                                   [self config]);
  XCTAssertEqualObjects(UIPasteboard.generalPasteboard.string, @"before");
  XCTAssertNil([UIPasteboard.generalPasteboard dataForPasteboardType:@"com.example.context"]);
}
- (void)testPartialConfiguredLinkRetainsItsIdentity
{
  copyAttributedStringToPasteboard([[self selection] attributedSubstringFromRange:NSMakeRange(9, 3)], nil,
                                   [self config]);
  XCTAssertEqualObjects(UIPasteboard.generalPasteboard.string, @"[Context](ref:one)");
}
- (void)testCopyAsMarkdownKeepsMarkdownAndAddsMetadata
{
  NSString *markdown = @"before [Context](ref:one) after";
  copySelectionMarkdownToPasteboard(markdown, [self selection], [self config]);
  XCTAssertEqualObjects(UIPasteboard.generalPasteboard.string, markdown);
  XCTAssertNotNil([UIPasteboard.generalPasteboard dataForPasteboardType:@"com.example.context"]);
}
@end
