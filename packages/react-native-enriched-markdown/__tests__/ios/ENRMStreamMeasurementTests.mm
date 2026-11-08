#include "../../ios/internals/MeasurementCache.h"
#include "../../ios/utils/ENRMLaidOutSize.h"
#import <XCTest/XCTest.h>

using facebook::react::ENRMChooseMeasurement;
using facebook::react::ENRMMarkdownExtends;
using facebook::react::ENRMMeasurementSource;

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

// Arguments: streamUpdate, grew, viewAskedForHeight, hasView, hasLaidOutSize, samePreviousWidth.
- (void)testAStreamsUpdateTakesTheViewsSize
{
  XCTAssertEqual(ENRMChooseMeasurement(true, true, false, true, true, true), ENRMMeasurementSource::LaidOut);
  // The view laid out a render and asked again: its size is the current one.
  XCTAssertEqual(ENRMChooseMeasurement(true, false, true, true, true, true), ENRMMeasurementSource::LaidOut);
}

// Yoga measures twice a pass: right after new content measured in full, the view
// still shows the previous document, so the second call gets the full result.
- (void)testTheSameDocumentAgainGetsThePreviousAnswer
{
  XCTAssertEqual(ENRMChooseMeasurement(true, false, false, true, true, true), ENRMMeasurementSource::Previous);
}

// A view sized to its content lays out narrower than offered: it keeps its size
// while the stream grows, and measures in full once it asks for a new height.
- (void)testAViewSizedToItsContentKeepsItsSizeUntilItAsks
{
  XCTAssertEqual(ENRMChooseMeasurement(true, true, false, true, false, true), ENRMMeasurementSource::Previous);
  XCTAssertEqual(ENRMChooseMeasurement(true, true, true, true, false, true), ENRMMeasurementSource::Full);
}

// Before the view mounts, nothing would ask for the grown document's height.
- (void)testAGrownDocumentWithoutAViewMeasuresInFull
{
  XCTAssertEqual(ENRMChooseMeasurement(true, true, false, false, false, true), ENRMMeasurementSource::Full);
  XCTAssertEqual(ENRMChooseMeasurement(true, false, false, false, false, true), ENRMMeasurementSource::Previous);
}

- (void)testNewContentOrAnotherWidthMeasuresInFull
{
  XCTAssertEqual(ENRMChooseMeasurement(false, false, false, true, true, true), ENRMMeasurementSource::Full);
  XCTAssertEqual(ENRMChooseMeasurement(true, false, false, true, false, false), ENRMMeasurementSource::Full);
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
