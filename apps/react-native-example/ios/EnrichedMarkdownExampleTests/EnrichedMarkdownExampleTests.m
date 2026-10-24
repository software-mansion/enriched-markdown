// Harness placeholder for the react-native-enriched-markdown iOS unit test
// target. It keeps the app-hosted XCTest bundle non-empty so the test lane is
// green before the real suites land. The library's XCTest sources live in
// packages/react-native-enriched-markdown/__tests__/ios and are added to this
// same target (see that dir's README / the test-target Compile Sources phase).
#import <XCTest/XCTest.h>

@interface EnrichedMarkdownExampleTests : XCTestCase
@end

@implementation EnrichedMarkdownExampleTests

- (void)testHarnessRuns
{
  XCTAssertTrue(YES, @"iOS unit test target is wired and running");
}

@end
