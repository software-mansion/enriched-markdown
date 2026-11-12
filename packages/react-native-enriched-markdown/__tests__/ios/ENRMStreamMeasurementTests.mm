#include "../../ios/internals/MeasurementCache.h"
#include "../../ios/internals/ShadowMeasurementUtils.h"
#include "../../ios/utils/ENRMLaidOutSize.h"
#import <XCTest/XCTest.h>

#include <string>

using facebook::react::ENRMCanTakeLaidOutSlotLayout;
using facebook::react::ENRMChooseMeasurement;
using facebook::react::ENRMGrowingTailSlotHeight;
using facebook::react::ENRMIsStreamUpdate;
using facebook::react::ENRMMarkdownExtends;
using facebook::react::ENRMMeasuredSlot;
using facebook::react::ENRMMeasurementSource;
using facebook::react::ENRMPreviousMeasurement;
using facebook::react::ENRMShownSlot;
using facebook::react::ENRMStreamingRenderEqual;
using facebook::react::MeasurementCacheKey;

// The fields ENRMIsStreamUpdate reads, as codegen generates them on the components' props.
struct ENRMStreamMeasurementProps {
  std::string markdown;
  bool streaming = true;
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

// The props ENRMStreamingRenderEqual reads.
struct ENRMStreamTestProps {
  bool streaming = true;
  struct {
    std::string tableMode = "progressive";
    std::string codeBlockMode = "progressive";
    std::string mediaMode = "progressive";
    std::string animation = "fade";
  } streamingConfig;
};

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

// The animation changes no layout, so flipping it keeps a stream's update.
- (void)testAnotherAnimationKeepsTheStreamUpdateButAnotherModeDoesNot
{
  ENRMStreamTestProps fading;
  ENRMStreamTestProps still = fading;
  still.streamingConfig.animation = "none";
  XCTAssertTrue(ENRMStreamingRenderEqual(fading, still));

  ENRMStreamTestProps hiddenTables = fading;
  hiddenTables.streamingConfig.tableMode = "hidden";
  XCTAssertFalse(ENRMStreamingRenderEqual(fading, hiddenTables));

  ENRMStreamTestProps ended = fading;
  ended.streaming = false;
  XCTAssertFalse(ENRMStreamingRenderEqual(fading, ended));
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

// Documents with block slots: the view's height stands when it shows every slot where the last
// full measurement placed it (ENRMCanTakeLaidOutSlotLayout).
static bool ENRMTakes(const std::vector<ENRMMeasuredSlot> &measured, const std::vector<ENRMShownSlot> &shown,
                      double height = 900, bool smooth = false)
{
  return ENRMCanTakeLaidOutSlotLayout(smooth, height, measured, shown, 1.0 / 3);
}

- (void)testAStreamTakesTheViewsHeightWhenEverySlotIsWhereItWasMeasured
{
  std::vector<ENRMMeasuredSlot> measured = {{"code:a", 100, 200, true, 200}, {"code:b", 500, 120, true, 120}};
  std::vector<ENRMShownSlot> shown = {{"code:a", 100, 200}, {"code:b", 500.2, 120}};
  XCTAssertTrue(ENRMTakes(measured, shown));
  XCTAssertFalse(ENRMTakes(measured, shown, 0));
  XCTAssertFalse(ENRMTakes({}, {}));
}

- (void)testASlotThatMovedOrResizedMeasuresInFull
{
  std::vector<ENRMShownSlot> shown = {{"code:a", 100, 200}};
  // An image above it loaded: the view moved it.
  XCTAssertFalse(ENRMTakes({{"code:a", 60, 200, true, 200}}, shown));
  // Its child grew (a code block still streaming into its renderer).
  XCTAssertFalse(ENRMTakes({{"code:a", 100, 200, true, 260}}, shown));
  // The view still shows the height it reserved before.
  XCTAssertFalse(ENRMTakes({{"code:a", 100, 240, true, 240}}, shown));
  // Not placed by the measurement.
  XCTAssertFalse(ENRMTakes({{"code:a", 100, 200, false, 200}}, shown));
}

- (void)testASlotTheViewDoesNotShowMeasuresInFullUnlessPacingHidesIt
{
  std::vector<ENRMMeasuredSlot> measured = {{"code:a", 100, 200, true, 200}, {"code:b", 950, 120, true, 120}};
  std::vector<ENRMShownSlot> shown = {{"code:a", 100, 200}};
  // Placed, but the view hasn't applied it yet (or it sits in a quote).
  XCTAssertFalse(ENRMTakes(measured, shown));
  // Smooth pacing hasn't revealed it: below what the view shows.
  XCTAssertTrue(ENRMTakes(measured, shown, 900, /*smooth*/ true));
  // Revealed text reaches past it, so the view should show it.
  XCTAssertFalse(ENRMTakes({{"code:a", 100, 200, true, 200}, {"code:b", 600, 120, true, 120}}, shown, 900, true));
  // The view shows a slot the measurement doesn't know.
  XCTAssertFalse(ENRMTakes({{"code:a", 100, 200, true, 200}}, {{"code:a", 100, 200}, {"code:c", 400, 80}}));
}

- (void)testTheLaidOutLayoutKeepsItsSlotsWithItsSize
{
  ENRMLaidOutSize laidOut;
  auto slots = std::make_shared<const std::vector<ENRMLaidOutSlot>>(std::vector<ENRMLaidOutSlot>{{"code:a", 40, 200}});
  laidOut.store(320, CGSizeMake(320, 700), std::make_shared<const std::string>("Intro"), slots);
  ENRMLaidOutLayout layout = laidOut.layoutFor(320, 3, "Intro and more");
  XCTAssertEqual(layout.size.height, 700);
  XCTAssertEqual(layout.slots->size(), 1u);
  XCTAssertEqual(layout.slots->front().y, 40);
  XCTAssertTrue(laidOut.layoutFor(300, 3, "Intro and more").slots == nullptr);
  XCTAssertTrue(laidOut.layoutFor(320, 3, "Other").slots == nullptr);
}

- (void)testACodeBlockStreamingIntoTheLastSlotGrowsTheDocumentByItsChild
{
  // The last full measurement: the slot at 500, 120 high, 8 below it.
  std::vector<ENRMMeasuredSlot> measured = {{"code:a", 100, 200, true, 200}, {"code:b", 500, 120, true, 160}};
  std::vector<ENRMShownSlot> shown = {{"code:a", 100, 200}, {"code:b", 500, 120}};
  const double third = 1.0 / 3;
  XCTAssertEqualWithAccuracy(ENRMGrowingTailSlotHeight(true, 628, 628, measured, shown, third), 668, 0.001);
  // Not inside the open fence: the slot isn't the document's end.
  XCTAssertEqual(ENRMGrowingTailSlotHeight(false, 628, 628, measured, shown, third), 0);
  // The view lays out more after the slot.
  XCTAssertEqual(ENRMGrowingTailSlotHeight(true, 628, 700, measured, shown, third), 0);
  // A slot above it moved.
  std::vector<ENRMShownSlot> moved = {{"code:a", 120, 200}, {"code:b", 520, 120}};
  XCTAssertEqual(ENRMGrowingTailSlotHeight(true, 628, 648, measured, moved, third), 0);
  // The view hasn't applied the last slot's placement yet.
  XCTAssertEqual(ENRMGrowingTailSlotHeight(true, 628, 300, measured, {{"code:a", 100, 200}}, third), 0);
}

// A take grew the last slot to 160; the next update arrives before the view laid that out.
- (void)testASecondTailUpdateBeforeTheViewCaughtUpMeasuresInFull
{
  std::vector<ENRMMeasuredSlot> measured = {{"code:a", 100, 200, true, 200}, {"code:b", 500, 160, true, 200}};
  std::vector<ENRMShownSlot> shown = {{"code:a", 100, 200}, {"code:b", 500, 120}};
  XCTAssertEqual(ENRMGrowingTailSlotHeight(true, 668, 628, measured, shown, 1.0 / 3), 0);
}

@end
