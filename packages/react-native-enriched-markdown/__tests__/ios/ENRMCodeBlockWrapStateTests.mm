#import "../../ios/utils/ENRMCodeBlockWrapState.h"
#import <XCTest/XCTest.h>

@interface ENRMCodeBlockWrapStateTests : XCTestCase
@end

@implementation ENRMCodeBlockWrapStateTests

- (void)testKeepsStateWhileTheDocumentGrows
{
  XCTAssertTrue(ENRMKeepsCodeBlockWrapState("a\nb", "a\nb\nc"));
  // The unfinished last line may be rewritten.
  XCTAssertTrue(ENRMKeepsCodeBlockWrapState("a\n<b", "a\n<br>\nc"));
  // A single-line document has no stable prefix yet.
  XCTAssertTrue(ENRMKeepsCodeBlockWrapState("abc", "xyz"));
}

- (void)testResetsWhenAnEarlierLineChanges
{
  XCTAssertFalse(ENRMKeepsCodeBlockWrapState("a\nb\nc", "x\nb\nc"));
  XCTAssertFalse(ENRMKeepsCodeBlockWrapState("a\nb\nc", "a\nx\nc"));
  // Shorter than the stable prefix.
  XCTAssertFalse(ENRMKeepsCodeBlockWrapState("a\nb\nc", "a\n"));
}

- (void)testCursorCountsInVisitOrder
{
  ENRMCodeBlockWrapCursor *cursor = [[ENRMCodeBlockWrapCursor alloc] initWithWrapped:[NSSet setWithArray:@[ @1, @3 ]]];
  XCTAssertFalse([cursor nextIsWrapped]);
  XCTAssertTrue([cursor nextIsWrapped]);
  XCTAssertFalse([cursor nextIsWrapped]);
  XCTAssertTrue([cursor nextIsWrapped]);
  XCTAssertFalse([cursor nextIsWrapped]);
}

@end
