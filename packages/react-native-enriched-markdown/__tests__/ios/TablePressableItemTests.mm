#import "../../ios/parser/ENRMMarkdownParser.h"
#import "../../ios/parser/MarkdownASTNode.h"
#import "../../ios/segments/ENRMTableIOSGridView.h"
#import "../../ios/segments/TableContainerView.h"
#import "../../ios/styles/StyleConfig.h"
#import "../../ios/utils/ENRMHorizontalScrollView.h"
#import <React/RCTSurfaceTouchHandler.h>
#import <XCTest/XCTest.h>

static id ENRMFindSubview(UIView *view, Class cls)
{
  if ([view isKindOfClass:cls]) {
    return view;
  }
  for (UIView *subview in view.subviews) {
    id found = ENRMFindSubview(subview, cls);
    if (found) {
      return found;
    }
  }
  return nil;
}

@interface TablePressableItemTests : XCTestCase
@end

// The root hands a table touch to React Native unless it lands on a link, or an image with image
// presses on (#1252).
@implementation TablePressableItemTests {
  TableContainerView *_table;
  ENRMTableIOSGridView *_grid;
}

- (void)setUp
{
  StyleConfig *config = [[StyleConfig alloc] init];
  [config setTableFontSize:16];
  [config setInlineImageSize:16];
  [config setImageHeight:16];
  MarkdownASTNode *ast = [[[ENRMMarkdownParser alloc] init]
      parseMarkdown:
          @"| A | B | C |\n| --- | --- | --- |\n| [link](https://l.example) | plain text here | "
          @"![img](https://i.example/a.png) |\n"
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
  // Narrower than the grid, so the table scrolls.
  _table.frame = CGRectMake(0, 0, 120, [_table measureHeight:120]);
  [_table layoutIfNeeded];
  _grid = ENRMFindSubview(_table, [ENRMTableIOSGridView class]);
}

- (ENRMTableIOSItemHit *)firstHitOfKind:(ENRMTableIOSItemKind)kind
{
  for (CGFloat y = 1; y < _grid.bounds.size.height; y += 2) {
    for (CGFloat x = 1; x < _grid.bounds.size.width; x += 2) {
      ENRMTableIOSItemHit *hit = [_grid itemAtPoint:CGPointMake(x, y)];
      if (hit && hit.kind == kind) {
        return hit;
      }
    }
  }
  return nil;
}

- (BOOL)pressableAtGridPoint:(CGPoint)gridPoint includeImages:(BOOL)includeImages
{
  return [_table hasPressableItemAtPoint:[_grid convertPoint:gridPoint toView:_table] includeImages:includeImages];
}

- (void)testOnlyLinksAndPressableImagesBelongToTheTable
{
  ENRMTableIOSItemHit *link = [self firstHitOfKind:ENRMTableIOSItemKindLink];
  ENRMTableIOSItemHit *image = [self firstHitOfKind:ENRMTableIOSItemKindImage];
  XCTAssertNotNil(link);
  XCTAssertNotNil(image);
  CGPoint linkPoint = CGPointMake(CGRectGetMidX(link.frame), CGRectGetMidY(link.frame));
  CGPoint imagePoint = CGPointMake(CGRectGetMidX(image.frame), CGRectGetMidY(image.frame));
  // The plain cell's text, on the link's line, and the padding at the grid's corner.
  CGPoint plainPoint = CGPointMake((CGRectGetMaxX(link.frame) + CGRectGetMinX(image.frame)) / 2, linkPoint.y);

  XCTAssertTrue([self pressableAtGridPoint:linkPoint includeImages:NO]);
  XCTAssertFalse([self pressableAtGridPoint:plainPoint includeImages:YES]);
  XCTAssertFalse([self pressableAtGridPoint:CGPointMake(1, 1) includeImages:YES]);
  XCTAssertFalse([self pressableAtGridPoint:imagePoint includeImages:NO]);
  XCTAssertTrue([self pressableAtGridPoint:imagePoint includeImages:YES]);

  // Scrolled, a point of the table maps to the grid point under it.
  ENRMHorizontalScrollView *scrollView = ENRMFindSubview(_table, [ENRMHorizontalScrollView class]);
  XCTAssertGreaterThan(scrollView.contentSize.width, _table.bounds.size.width);
  CGPoint unscrolled = [_grid convertPoint:imagePoint toView:_table];
  CGFloat offset = CGRectGetMinX(image.frame) - 10;
  scrollView.contentOffset = CGPointMake(offset, 0);
  XCTAssertTrue([_table hasPressableItemAtPoint:CGPointMake(unscrolled.x - offset, unscrolled.y) includeImages:YES]);
  XCTAssertFalse([_table hasPressableItemAtPoint:unscrolled includeImages:YES]);
}

@end

@interface ENRMHorizontalScrollView (TablePressableItemTests)
- (void)enrm_handlePan:(UIPanGestureRecognizer *)pan;
@end

@interface ENRMRecordingTouchHandler : RCTSurfaceTouchHandler
@property (nonatomic) NSInteger disableCount;
@end

@implementation ENRMRecordingTouchHandler
- (void)setEnabled:(BOOL)enabled
{
  if (!enabled) {
    self.disableCount++;
  }
  [super setEnabled:enabled];
}
@end

@interface ENRMBeganPan : UIPanGestureRecognizer
@end

@implementation ENRMBeganPan
- (UIGestureRecognizerState)state
{
  return UIGestureRecognizerStateBegan;
}
@end

@interface ENRMHorizontalScrollTouchCancelTests : XCTestCase
@end

@implementation ENRMHorizontalScrollTouchCancelTests

// A horizontal block's pan doesn't prevent React Native's touch handler, so it cancels the touch itself;
// otherwise a drag across a wide table ends in a parent Pressable's onPress.
- (void)testAHorizontalPanCancelsTheReactNativeTouch
{
  UIView *surface = [[UIView alloc] init];
  ENRMRecordingTouchHandler *handler = [[ENRMRecordingTouchHandler alloc] init];
  [handler attachToView:surface];
  UIView *block = [[UIView alloc] init];
  [surface addSubview:block];
  ENRMHorizontalScrollView *scrollView = [[ENRMHorizontalScrollView alloc] initWithFrame:CGRectMake(0, 0, 100, 50)];
  [block addSubview:scrollView];

  [scrollView enrm_handlePan:[[ENRMBeganPan alloc] init]];

  XCTAssertEqual(handler.disableCount, 1);
  XCTAssertTrue(handler.enabled);
}

@end
