#import "../../ios/parser/ENRMMarkdownParser.h"
#import "../../ios/parser/MarkdownASTNode.h"
#import "../../ios/segments/ENRMTableIOSGridView.h"
#import "../../ios/segments/TableContainerView.h"
#import "../../ios/styles/StyleConfig.h"
#import <XCTest/XCTest.h>

@interface TableContainerView (TableLinkColorTests)
- (NSArray<NSArray<NSDictionary *> *> *)rowDictionariesForHTML;
@end

static UIView *ENRMFindGrid(UIView *view)
{
  if ([view isKindOfClass:[ENRMTableIOSGridView class]]) {
    return view;
  }
  for (UIView *subview in view.subviews) {
    UIView *grid = ENRMFindGrid(subview);
    if (grid) {
      return grid;
    }
  }
  return nil;
}

@interface TableLinkColorTests : XCTestCase
@end

@implementation TableLinkColorTests {
  TableContainerView *_table;
}

- (void)setUp
{
  StyleConfig *config = [[StyleConfig alloc] init];
  [config setTableFontSize:20];
  [config setLinkColor:[UIColor colorWithRed:1 green:0 blue:0 alpha:1]];
  [config setTableHeaderTextColor:[UIColor blackColor]];
  [config setTableHeaderBackgroundColor:[UIColor whiteColor]];
  [config setTableRowEvenBackgroundColor:[UIColor whiteColor]];
  [config setTableRowOddBackgroundColor:[UIColor whiteColor]];
  MarkdownASTNode *ast = [[[ENRMMarkdownParser alloc] init]
      parseMarkdown:@"| [header](https://h.example) |\n| --- |\n| [body link](https://b.example) |\n"
              flags:[ENRMMd4cFlags defaultFlags]
              isGFM:YES];
  MarkdownASTNode *tableNode = nil;
  for (MarkdownASTNode *node in ast.children) {
    if (node.type == MarkdownNodeTypeTable) {
      tableNode = node;
    }
  }
  _table = [[TableContainerView alloc] initWithConfig:config];
  [_table applyTableNode:tableNode];
  _table.frame = CGRectMake(0, 0, 320, [_table measureHeight:320]);
  [_table layoutIfNeeded];
}

// String drawing paints NSLinkAttributeName in the system link color, so the grid draws cell text
// without it (#1240).
- (void)testCellLinksAreDrawnInTheConfiguredColor
{
  UIView *grid = ENRMFindGrid(_table);
  XCTAssertNotNil(grid);

  UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
  format.scale = 1;
  UIImage *image = [[[UIGraphicsImageRenderer alloc] initWithSize:grid.bounds.size format:format]
      imageWithActions:^(UIGraphicsImageRendererContext *context) { [grid drawRect:grid.bounds]; }];

  CGImageRef cgImage = image.CGImage;
  size_t width = CGImageGetWidth(cgImage), height = CGImageGetHeight(cgImage);
  NSMutableData *pixels = [NSMutableData dataWithLength:width * height * 4];
  CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
  CGContextRef context = CGBitmapContextCreate(pixels.mutableBytes, width, height, 8, width * 4, space,
                                               (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
  CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgImage);
  CGContextRelease(context);
  CGColorSpaceRelease(space);

  NSUInteger red = 0, blue = 0;
  const uint8_t *bytes = (const uint8_t *)pixels.bytes;
  for (size_t i = 0; i < width * height; i++) {
    const uint8_t *p = bytes + i * 4;
    if (p[0] > 200 && p[1] < 80 && p[2] < 80) {
      red++;
    } else if (p[2] > 180 && p[0] < 80) {
      blue++;
    }
  }
  XCTAssertGreaterThan(red, 40u);
  XCTAssertEqual(blue, 0u);
}

// Copy as HTML reads the cells, which keep the link for its <a href>.
- (void)testCellsKeepTheirLinkForCopyAsHTML
{
  NSArray<NSArray<NSDictionary *> *> *rows = [_table rowDictionariesForHTML];
  NSAttributedString *body = rows.lastObject.firstObject[@"attributedText"];
  id link = [body attribute:NSLinkAttributeName atIndex:0 effectiveRange:NULL];
  XCTAssertEqualObjects([link description], @"https://b.example");
}

@end
