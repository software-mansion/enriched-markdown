#import "../../ios/internals/ENRMPreparedRenderStore.h"
#import <XCTest/XCTest.h>

#include <vector>

// Stands in for a props object: the store compares only its identity.
using ENRMTestProps = std::shared_ptr<const void>;

static ENRMPreparedRenderKey ENRMTestKey(const ENRMTestProps &props, NSSet<NSString *> *slotIds = nil)
{
  return {props, 1.0, NSWritingDirectionLeftToRight, slotIds};
}

@interface ENRMPreparedRenderStoreTests : XCTestCase
@end

@implementation ENRMPreparedRenderStoreTests

- (void)testTakesWhatWasPreparedOnce
{
  auto props = std::make_shared<const int>(0);
  NSArray *rendered = @[ @"segment" ];
  XCTAssertEqual([ENRMPreparedRenderStore prepareForKey:ENRMTestKey(props) render:^id { return rendered; }], rendered);

  XCTAssertEqual(ENRMTakePreparedSegments(ENRMTestKey(props)), rendered);
  XCTAssertNil(ENRMTakePreparedSegments(ENRMTestKey(props)));
}

- (void)testRendersOncePerProps
{
  auto props = std::make_shared<const int>(0);
  __block int renders = 0;
  id (^render)(void) = ^id {
    renders++;
    return @[];
  };

  [ENRMPreparedRenderStore prepareForKey:ENRMTestKey(props) render:render];
  XCTAssertNil([ENRMPreparedRenderStore prepareForKey:ENRMTestKey(props) render:render]);
  XCTAssertEqual(renders, 1);

  // Taken: later layout passes over the same props, before the shadow node
  // learns the view mounted, must not render it again.
  ENRMTakePreparedSegments(ENRMTestKey(props));
  XCTAssertNil([ENRMPreparedRenderStore prepareForKey:ENRMTestKey(props) render:render]);
  XCTAssertEqual(renders, 1);
}

- (void)testNilRenderKeepsNothing
{
  auto props = std::make_shared<const int>(0);
  __block int renders = 0;
  id (^render)(void) = ^id {
    renders++;
    return nil;
  };

  XCTAssertNil([ENRMPreparedRenderStore prepareForKey:ENRMTestKey(props) render:render]);
  XCTAssertNil([ENRMPreparedRenderStore prepareForKey:ENRMTestKey(props) render:render]);
  XCTAssertEqual(renders, 2);
  XCTAssertNil(ENRMTakePreparedSegments(ENRMTestKey(props)));
}

- (void)testInputsOutsideThePropsMustMatch
{
  auto scaled = std::make_shared<const int>(0);
  [ENRMPreparedRenderStore prepareForKey:ENRMTestKey(scaled) render:^id { return @[]; }];
  XCTAssertNil(ENRMTakePreparedSegments({scaled, 1.3, NSWritingDirectionLeftToRight, nil}));

  auto rtl = std::make_shared<const int>(0);
  [ENRMPreparedRenderStore prepareForKey:ENRMTestKey(rtl) render:^id { return @[]; }];
  XCTAssertNil(ENRMTakePreparedSegments({rtl, 1.0, NSWritingDirectionRightToLeft, nil}));

  auto slotted = std::make_shared<const int>(0);
  [ENRMPreparedRenderStore prepareForKey:ENRMTestKey(slotted, [NSSet setWithObject:@"b1"]) render:^id { return @[]; }];
  XCTAssertNil(ENRMTakePreparedSegments(ENRMTestKey(slotted, [NSSet setWithObject:@"b2"])));
}

- (void)testNoSlotsMatchesAnEmptySet
{
  auto props = std::make_shared<const int>(0);
  NSArray *rendered = @[];
  [ENRMPreparedRenderStore prepareForKey:ENRMTestKey(props, [NSSet set]) render:^id { return rendered; }];
  XCTAssertEqual(ENRMTakePreparedSegments(ENRMTestKey(props, nil)), rendered);
}

- (void)testAnotherPropsObjectDoesNotMatch
{
  auto measured = std::make_shared<const int>(0);
  auto other = std::make_shared<const int>(0);
  [ENRMPreparedRenderStore prepareForKey:ENRMTestKey(measured) render:^id { return @[]; }];
  XCTAssertNil(ENRMTakePreparedSegments(ENRMTestKey(other)));
  XCTAssertNotNil(ENRMTakePreparedSegments(ENRMTestKey(measured)));
}

- (void)testTakeChecksTheResultType
{
  auto props = std::make_shared<const int>(0);
  [ENRMPreparedRenderStore prepareForKey:ENRMTestKey(props) render:^id { return @[]; }];
  XCTAssertNil(ENRMTakePreparedText(ENRMTestKey(props)));
}

- (void)testKeepsTheNewestRenders
{
  std::vector<ENRMTestProps> props;
  for (int i = 0; i < 300; i++) {
    props.push_back(std::make_shared<const int>(0));
    [ENRMPreparedRenderStore prepareForKey:ENRMTestKey(props.back()) render:^id { return @[]; }];
  }
  XCTAssertNil(ENRMTakePreparedSegments(ENRMTestKey(props.front())));
  XCTAssertNotNil(ENRMTakePreparedSegments(ENRMTestKey(props.back())));
}

@end
