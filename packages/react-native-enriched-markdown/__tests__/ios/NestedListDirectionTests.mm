#import "../../ios/segments/ENRMBlockquoteContainerView.h"
#import "../../ios/segments/ENRMListContainerView.h"
#import <XCTest/XCTest.h>

@interface ENRMDirectionTestItem : ENRMContainerNodeView
@property (nonatomic, copy) NSArray<RCTUIView *> *children;
@end
@implementation ENRMDirectionTestItem
- (NSArray<RCTUIView *> *)segmentViews
{
  return self.children ?: @[];
}
@end

@interface ENRMDirectionTestList : ENRMListContainerView
@property (nonatomic, copy) NSArray<RCTUIView *> *items;
@property (nonatomic, assign) NSUInteger directionUpdates;
@end
@implementation ENRMDirectionTestList
- (NSArray<RCTUIView *> *)segmentViews
{
  return self.items ?: @[];
}
- (void)setOuterDirection:(NSWritingDirection)direction
{
  self.directionUpdates++;
  [super setOuterDirection:direction];
}
@end

@interface ENRMDirectionTestQuote : ENRMBlockquoteContainerView
@property (nonatomic, copy) NSArray<RCTUIView *> *children;
@end
@implementation ENRMDirectionTestQuote
- (NSArray<RCTUIView *> *)segmentViews
{
  return self.children ?: @[];
}
@end

static ENRMDirectionTestItem *ENRMDirectionItem(RCTUIView *child)
{
  ENRMDirectionTestItem *item = [[ENRMDirectionTestItem alloc] initWithFrame:CGRectZero];
  item.children = child ? @[ child ] : @[];
  return item;
}

@interface ENRMNestedListDirectionTests : XCTestCase
@end
@implementation ENRMNestedListDirectionTests
- (void)testDirectionUpdatesVisitEachNestedListOnce
{
  for (NSNumber *depth in @[ @4, @10 ]) {
    StyleConfig *config = [StyleConfig new];
    NSMutableArray<ENRMDirectionTestList *> *lists = [NSMutableArray array];
    ENRMDirectionTestList *child = nil;
    for (NSUInteger index = 0; index < depth.unsignedIntegerValue; index++) {
      ENRMDirectionTestList *list = [[ENRMDirectionTestList alloc] initWithConfig:config];
      list.items = @[ ENRMDirectionItem(child) ];
      [lists addObject:list];
      child = list;
    }
    ENRMDirectionTestQuote *quote = [[ENRMDirectionTestQuote alloc] initWithConfig:config];
    quote.children = @[ child ];
    quote.outerDirection = NSWritingDirectionRightToLeft;
    NSUInteger updates = 0;
    for (ENRMDirectionTestList *list in lists) {
      updates += list.directionUpdates;
      XCTAssertEqual(list.outerDirection, NSWritingDirectionRightToLeft);
    }
    XCTAssertEqual(updates, depth.unsignedIntegerValue);
  }
}

- (void)testUnchangedQuoteDirectionStillReachesNewChildLists
{
  StyleConfig *config = [StyleConfig new];
  ENRMDirectionTestQuote *quote = [[ENRMDirectionTestQuote alloc] initWithConfig:config];
  quote.outerDirection = NSWritingDirectionRightToLeft;
  ENRMDirectionTestList *child = [[ENRMDirectionTestList alloc] initWithConfig:config];
  quote.children = @[ child ];
  ENRMDirectionTestList *root = [[ENRMDirectionTestList alloc] initWithConfig:config];
  root.items = @[ ENRMDirectionItem(quote) ];
  root.outerDirection = NSWritingDirectionRightToLeft;
  XCTAssertEqual(child.outerDirection, NSWritingDirectionRightToLeft);
  XCTAssertEqual(child.directionUpdates, 1u);
}
@end
