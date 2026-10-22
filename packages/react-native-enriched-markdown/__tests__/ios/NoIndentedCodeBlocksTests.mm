#import "../../ios/generated/ReactCodegen/EnrichedMarkdownTextSpec/Props.h"
#import "../../ios/internals/ENRMViewFreeMeasurement.h"
#import "../../ios/internals/ShadowMeasurementUtils.h"
#import <XCTest/XCTest.h>

using namespace facebook::react;

@interface ENRMNoIndentedCodeBlocksTests : XCTestCase
@end

@implementation ENRMNoIndentedCodeBlocksTests

- (void)testMeasurementCacheAndStreamingInvalidationIncludeIndentedCodeOption
{
  EnrichedMarkdownTextProps off;
  off.markdown = "    **Indented prose**";
  EnrichedMarkdownTextProps on;
  on.markdown = off.markdown;
  on.md4cFlags.noIndentedCodeBlocks = true;
  const auto offKey = buildMeasurementCacheKey(off, 300, 1, MarkdownFlavor::CommonMark);
  const auto onKey = buildMeasurementCacheKey(on, 300, 1, MarkdownFlavor::CommonMark);
  XCTAssertFalse(offKey == onKey);
  XCTAssertTrue(ENRMPropsNeedExactStreamingMeasurement(off, on));
  XCTAssertTrue(ENRMPropsNeedExactStreamingMeasurement(on, off));
  MeasurementCache::shared().set(offKey, {100, 200});
  CachedSize size;
  XCTAssertFalse(MeasurementCache::shared().get(onKey, size));
  XCTAssertTrue(MeasurementCache::shared().get(offKey, size));
  XCTAssertEqual(size.height, 200);
  MeasurementCache::shared().removeMatchingMarkdown(off.markdown);
}

- (void)testMeasurementParsesIndentedProseWithTheSameOptionAsTheRenderer
{
  EnrichedMarkdownTextProps props;
  props.markdown = "    **Indented prose**";
  const auto offSize = ENRMMeasureMarkdownViewFree(props, 300, 1, 3, NSWritingDirectionLeftToRight);
  for (bool enabled : {true, false}) {
    props.md4cFlags.noIndentedCodeBlocks = enabled;
    const auto size = ENRMMeasureMarkdownViewFree(props, 300, 1, 3, NSWritingDirectionLeftToRight);
    ENRMMd4cFlags *flags = ENRMMd4cFlagsFromProps(props.md4cFlags);
    XCTAssertEqual(flags.noIndentedCodeBlocks, enabled);
    XCTAssertEqual([(ENRMMd4cFlags *)[flags copy] noIndentedCodeBlocks], enabled);
    if (enabled) {
      EnrichedMarkdownTextProps plain;
      plain.md4cFlags = props.md4cFlags;
      plain.markdown = "**Indented prose**";
      const auto expected = ENRMMeasureMarkdownViewFree(plain, 300, 1, 3, NSWritingDirectionLeftToRight);
      XCTAssertEqualWithAccuracy(size.height, expected.height, 0.5);
      XCTAssertEqualWithAccuracy(size.width, expected.width, 0.5);
      XCTAssertNotEqual(size.height, offSize.height);
    } else {
      XCTAssertEqualWithAccuracy(size.height, offSize.height, 0.5);
      XCTAssertEqualWithAccuracy(size.width, offSize.width, 0.5);
    }
  }
}

- (void)testSegmentedMeasurementUpdatesWhenOnlyTheOptionChanges
{
  EnrichedMarkdownProps props;
  props.markdown = "    **Indented prose**";
  props.isGFM = true;
  const auto offSize = ENRMMeasureSegmentedMarkdownViewFree(props, 300, 1, 3, NSWritingDirectionLeftToRight);
  for (bool enabled : {true, false}) {
    props.md4cFlags.noIndentedCodeBlocks = enabled;
    const auto size = ENRMMeasureSegmentedMarkdownViewFree(props, 300, 1, 3, NSWritingDirectionLeftToRight);
    if (enabled) {
      EnrichedMarkdownProps plain;
      plain.markdown = "**Indented prose**";
      plain.isGFM = true;
      plain.md4cFlags.noIndentedCodeBlocks = true;
      const auto expected = ENRMMeasureSegmentedMarkdownViewFree(plain, 300, 1, 3, NSWritingDirectionLeftToRight);
      XCTAssertEqualWithAccuracy(size.height, expected.height, 0.5);
      XCTAssertNotEqual(size.height, offSize.height);
    } else {
      XCTAssertEqualWithAccuracy(size.height, offSize.height, 0.5);
    }
  }
}

@end
