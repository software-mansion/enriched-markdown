#include "../../ios/internals/MeasurementCache.h"
#include "../../ios/internals/ShadowMeasurementUtils.h"
#include "../../ios/utils/ENRMLaidOutSize.h"
#import <XCTest/XCTest.h>

using facebook::react::ENRMChooseMeasurement;
using facebook::react::ENRMIsStreamUpdate;
using facebook::react::ENRMMarkdownExtends;
using facebook::react::ENRMMeasurementSource;
using facebook::react::ENRMPreviousMeasurement;
using facebook::react::MeasurementCacheKey;

// The fields ENRMIsStreamUpdate reads, as codegen generates them on the components' props.
struct ENRMStreamMeasurementProps {
  std::string markdown;
  bool streamingAnimation = true;
  struct {
    int tableMode = 0;
    int codeBlockMode = 0;
    int mediaMode = 0;
  } streamingConfig;
};

static ENRMPreviousMeasurement<ENRMStreamMeasurementProps>
ENRMPreviouslyMeasured(const ENRMStreamMeasurementProps &props, const MeasurementCacheKey &layoutKey)
{
  ENRMPreviousMeasurement<ENRMStreamMeasurementProps> previous;
  previous.props = std::make_shared<const ENRMStreamMeasurementProps>(props);
  previous.layoutKey = layoutKey;
  previous.layoutDirection = NSWritingDirectionLeftToRight;
  return previous;
}

@interface ENRMStreamMeasurementTests : XCTestCase
@end

@implementation ENRMStreamMeasurementTests

- (void)testOnlyMarkdownThatKeepsAllOfThePreviousExtendsIt
{
  XCTAssertTrue(ENRMMarkdownExtends("Streaming **mark", "Streaming **markdown**"));
  XCTAssertTrue(ENRMMarkdownExtends("Same", "Same"));
  XCTAssertFalse(ENRMMarkdownExtends("Streaming", "Streamed"));
  XCTAssertFalse(ENRMMarkdownExtends("Longer text", "Longer"));
  // Nothing laid out yet, so there is no size to keep.
  XCTAssertFalse(ENRMMarkdownExtends("", "First chunk"));
}

- (void)testAStreamsUpdateTakesTheViewsSize
{
  XCTAssertEqual(
      ENRMChooseMeasurement(
          {.streamUpdate = true, .grew = true, .hasView = true, .hasLaidOutSize = true, .samePreviousWidth = true}),
      ENRMMeasurementSource::LaidOut);
  // The view laid out a render and asked again: its size is the current one.
  XCTAssertEqual(ENRMChooseMeasurement({.streamUpdate = true,
                                        .viewAskedForHeight = true,
                                        .hasView = true,
                                        .hasLaidOutSize = true,
                                        .samePreviousWidth = true}),
                 ENRMMeasurementSource::LaidOut);
}

// Yoga measures twice a pass: right after new content measured in full, the view
// still shows the previous document, so the second call gets the full result.
- (void)testTheSameDocumentAgainGetsThePreviousAnswer
{
  XCTAssertEqual(
      ENRMChooseMeasurement({.streamUpdate = true, .hasView = true, .hasLaidOutSize = true, .samePreviousWidth = true}),
      ENRMMeasurementSource::Previous);
}

// A view sized to its content lays out narrower than offered: it keeps its size
// while the stream grows, and measures in full once it asks for a new height.
- (void)testAViewSizedToItsContentKeepsItsSizeUntilItAsks
{
  XCTAssertEqual(
      ENRMChooseMeasurement({.streamUpdate = true, .grew = true, .hasView = true, .samePreviousWidth = true}),
      ENRMMeasurementSource::Previous);
  XCTAssertEqual(
      ENRMChooseMeasurement(
          {.streamUpdate = true, .grew = true, .viewAskedForHeight = true, .hasView = true, .samePreviousWidth = true}),
      ENRMMeasurementSource::Full);
}

// Before the view mounts, nothing would ask for the grown document's height.
- (void)testAGrownDocumentWithoutAViewMeasuresInFull
{
  XCTAssertEqual(ENRMChooseMeasurement({.streamUpdate = true, .grew = true, .samePreviousWidth = true}),
                 ENRMMeasurementSource::Full);
  XCTAssertEqual(ENRMChooseMeasurement({.streamUpdate = true, .samePreviousWidth = true}),
                 ENRMMeasurementSource::Previous);
}

- (void)testNewContentOrAnotherWidthMeasuresInFull
{
  XCTAssertEqual(ENRMChooseMeasurement({.hasView = true, .hasLaidOutSize = true, .samePreviousWidth = true}),
                 ENRMMeasurementSource::Full);
  XCTAssertEqual(ENRMChooseMeasurement({.streamUpdate = true, .hasView = true}), ENRMMeasurementSource::Full);
}

- (void)testOnlyGrownMarkdownWithEverythingElseUnchangedIsAStreamsUpdate
{
  const MeasurementCacheKey layoutKey{};
  const auto previous = ENRMPreviouslyMeasured({.markdown = "Streaming **mark"}, layoutKey);
  const ENRMStreamMeasurementProps grown{.markdown = "Streaming **markdown**"};
  XCTAssertTrue(ENRMIsStreamUpdate(previous, grown, layoutKey, NSWritingDirectionLeftToRight));
  XCTAssertTrue(
      ENRMIsStreamUpdate(previous, {.markdown = "Streaming **mark"}, layoutKey, NSWritingDirectionLeftToRight));

  XCTAssertFalse(ENRMIsStreamUpdate(previous, {.markdown = "Streamed"}, layoutKey, NSWritingDirectionLeftToRight));
  MeasurementCacheKey restyled = layoutKey;
  restyled.styleFingerprint = 1;
  XCTAssertFalse(ENRMIsStreamUpdate(previous, grown, restyled, NSWritingDirectionLeftToRight));
  XCTAssertFalse(ENRMIsStreamUpdate(previous, grown, layoutKey, NSWritingDirectionRightToLeft));
  ENRMStreamMeasurementProps otherMode = grown;
  otherMode.streamingConfig.tableMode = 1;
  XCTAssertFalse(ENRMIsStreamUpdate(previous, otherMode, layoutKey, NSWritingDirectionLeftToRight));
}

- (void)testTheFirstMeasurementIsNoStreamsUpdate
{
  XCTAssertFalse(ENRMIsStreamUpdate(ENRMPreviousMeasurement<ENRMStreamMeasurementProps>{}, {.markdown = "First chunk"},
                                    MeasurementCacheKey{}, NSWritingDirectionLeftToRight));
}

- (void)testLaidOutSizeIsOnlyForTheWidthItWasLaidOutAt
{
  ENRMLaidOutSize laidOut;
  XCTAssertTrue(CGSizeEqualToSize(laidOut.sizeFor(390, 3, "Streaming"), CGSizeZero));

  laidOut.store(390, CGSizeMake(370, 1200), ENRMLaidOutMarkdown(@"Streaming"));
  // Within a physical pixel: Yoga rounds the two edges of a frame separately.
  XCTAssertTrue(CGSizeEqualToSize(laidOut.sizeFor(390.2, 3, "Streaming"), CGSizeMake(370, 1200)));
  XCTAssertTrue(CGSizeEqualToSize(laidOut.sizeFor(380, 3, "Streaming"), CGSizeZero));

  laidOut.clear();
  XCTAssertTrue(CGSizeEqualToSize(laidOut.sizeFor(390, 3, "Streaming"), CGSizeZero));
}

// The view may still show the document a new stream replaced: its size isn't the stream's.
- (void)testLaidOutSizeIsOnlyForAnEarlierStateOfTheStream
{
  ENRMLaidOutSize laidOut;
  laidOut.store(390, CGSizeMake(370, 1200), ENRMLaidOutMarkdown(@"Streaming"));
  XCTAssertTrue(CGSizeEqualToSize(laidOut.sizeFor(390, 3, "Streaming on"), CGSizeMake(370, 1200)));
  XCTAssertTrue(CGSizeEqualToSize(laidOut.sizeFor(390, 3, "Stream"), CGSizeZero));
  XCTAssertTrue(CGSizeEqualToSize(laidOut.sizeFor(390, 3, "Another document"), CGSizeZero));
}

@end
