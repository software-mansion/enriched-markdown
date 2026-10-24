#import "EnrichedMarkdownShadowNode.h"
#import "ENRMBlockSlotMeasurer.h"
#import "ENRMViewFreeMeasurement.h"
#import "EnrichedMarkdown.h"
#import "ShadowMeasurementUtils.h"
#import <ReactNativeEnrichedMarkdown/ShadowNodes.h>
#include <cmath>
#include <limits>
#include <react/renderer/graphics/rounding.h>
#include <string_view>
#import <yoga/Yoga.h>

namespace facebook::react {

extern const char EnrichedMarkdownComponentName[] = "EnrichedMarkdown";

EnrichedMarkdownShadowNode::EnrichedMarkdownShadowNode(const ShadowNodeFragment &fragment,
                                                       const ShadowNodeFamily::Shared &family, ShadowNodeTraits traits)
    : ConcreteViewShadowNode(fragment, family, traits)
{
}

EnrichedMarkdownShadowNode::EnrichedMarkdownShadowNode(const ShadowNode &sourceShadowNode,
                                                       const ShadowNodeFragment &fragment)
    : ConcreteViewShadowNode(sourceShadowNode, fragment),
      localHeightRecalculationCounter_(
          static_cast<const EnrichedMarkdownShadowNode &>(sourceShadowNode).localHeightRecalculationCounter_),
      lastExactMeasurementCounter_(
          static_cast<const EnrichedMarkdownShadowNode &>(sourceShadowNode).lastExactMeasurementCounter_),
      lastExactMeasurementSize_(
          static_cast<const EnrichedMarkdownShadowNode &>(sourceShadowNode).lastExactMeasurementSize_),
      slotMeasurement_(static_cast<const EnrichedMarkdownShadowNode &>(sourceShadowNode).slotMeasurement_)
{
  const auto &oldProps = *std::static_pointer_cast<const EnrichedMarkdownProps>(sourceShadowNode.getProps());
  const auto &newProps = *std::static_pointer_cast<const EnrichedMarkdownProps>(this->getProps());

  if (newProps.streamingAnimation && ENRMPropsNeedExactStreamingMeasurement(oldProps, newProps)) {
    lastExactMeasurementCounter_ = -1;
  }

  // New children, e.g. every frame of an animation inside a slot: the next pass
  // re-checks the slot heights before reusing the measurement.
  if (fragment.children) {
    YGNodeMarkDirty(&yogaNode_);
    slotMeasurement_.slotHeightsChecked = false;
  }
  // The streaming modes decide what the walk renders but are not part of the
  // measurement key (the LRU cache is never used while streaming).
  if (fragment.props && (oldProps.streamingAnimation != newProps.streamingAnimation ||
                         oldProps.streamingConfig.tableMode != newProps.streamingConfig.tableMode ||
                         oldProps.streamingConfig.codeBlockMode != newProps.streamingConfig.codeBlockMode ||
                         oldProps.streamingConfig.mediaMode != newProps.streamingConfig.mediaMode)) {
    slotMeasurement_.valid = false;
  }

  dirtyLayoutIfNeeded();
}

void EnrichedMarkdownShadowNode::dirtyLayoutIfNeeded()
{
  const auto state = this->getStateData();
  const int receivedCounter = state.getHeightRecalculationCounter();

  if (receivedCounter > localHeightRecalculationCounter_) {
    localHeightRecalculationCounter_ = receivedCounter;
    YGNodeMarkDirty(&yogaNode_);
  }
}

// Order-independent fingerprint of the wrapped set for the cache key; 0 for none,
// and {0} still hashes apart from {}.
static size_t ENRMWrappedCodeBlocksFingerprint(NSSet<NSNumber *> *wrappedCodeBlocks)
{
  size_t h = 0;
  for (NSNumber *index in [wrappedCodeBlocks.allObjects sortedArrayUsingSelector:@selector(compare:)]) {
    HashUtils::hash_one(h, index.unsignedLongValue);
  }
  return h;
}

std::vector<EnrichedMarkdownShadowNode::SlotChild> EnrichedMarkdownShadowNode::slotChildren() const
{
  std::vector<SlotChild> slots;
  for (const auto &child : getChildren()) {
    // By component name, not RTTI: the slot's shadow node template is instantiated
    // in the app's autolinking library and typeinfo does not match across .so files.
    if (std::string_view(child->getComponentName()) != EnrichedMarkdownBlockSlotComponentName) {
      continue;
    }
    const auto *slot = static_cast<const EnrichedMarkdownBlockSlotShadowNode *>(child.get());
    slots.push_back({slot->getConcreteProps().slotId, slot});
  }
  return slots;
}

// The height a slot child is laid out at: Yoga-measured at `width`, rounded up
// to the pixel grid. An undefined host width is +inf; Yoga cannot take an
// infinite minimum, so the child is measured at its own width then.
static Float ENRMSlotChildHeight(const LayoutableShadowNode &node, const LayoutContext &layoutContext,
                                 LayoutDirection layoutDirection, CGFloat width)
{
  LayoutConstraints constraints;
  constraints.minimumSize = Size{std::isfinite(width) ? (Float)width : 0, 0};
  constraints.maximumSize = Size{(Float)width, std::numeric_limits<Float>::infinity()};
  constraints.layoutDirection = layoutDirection;
  Float height = node.measure(layoutContext, constraints).height;
  return roundToPixel<&ceil>(height, (Float)layoutContext.pointScaleFactor);
}

bool EnrichedMarkdownShadowNode::slotMeasurementMatches(const std::vector<SlotChild> &slots,
                                                        const MeasurementCacheKey &key, int counter, CGFloat width,
                                                        const LayoutContext &layoutContext,
                                                        LayoutDirection layoutDirection) const
{
  const auto &m = slotMeasurement_;
  if (!m.valid || m.counter != counter || m.width != width || m.frames.size() != slots.size() || !(m.key == key)) {
    return false;
  }
  for (size_t i = 0; i < slots.size(); i++) {
    if (m.frames[i].id != slots[i].id) {
      return false;
    }
  }
  return slotHeightsUnchanged(slots, layoutContext, layoutDirection);
}

// Laying a slot child out is cheap; measuring the document again is not.
bool EnrichedMarkdownShadowNode::slotHeightsUnchanged(const std::vector<SlotChild> &slots,
                                                      const LayoutContext &layoutContext,
                                                      LayoutDirection layoutDirection) const
{
  auto &m = slotMeasurement_;
  if (m.slotHeightsChecked) {
    return true;
  }
  for (size_t i = 0; i < slots.size(); i++) {
    const auto &frame = m.frames[i];
    if (frame.placed &&
        ENRMSlotChildHeight(*slots[i].node, layoutContext, layoutDirection, frame.width) != frame.height) {
      m.valid = false;
      return false;
    }
  }
  m.slotHeightsChecked = true;
  return true;
}

std::vector<ENRMBlockSlotPlacement> EnrichedMarkdownShadowNode::slotPlacements() const
{
  std::vector<ENRMBlockSlotPlacement> placements;
  placements.reserve(slotMeasurement_.frames.size());
  for (const auto &frame : slotMeasurement_.frames) {
    placements.push_back({frame.id, frame.height, frame.placed});
  }
  return placements;
}

// Measures the document with the slot children taking part: each slot is sized
// by Yoga-measuring its child at the width the walk gives it, and the frames the
// walk records are kept for layout(). An unchanged pass (same inputs, same
// children, same width) returns the previous result without re-parsing.
CGSize EnrichedMarkdownShadowNode::measureWithSlots(const std::vector<SlotChild> &slots,
                                                    const LayoutContext &layoutContext,
                                                    const LayoutConstraints &layoutConstraints, CGFloat maxWidth) const
{
  const auto &props = getConcreteProps();
  const int receivedCounter = getStateData().getHeightRecalculationCounter();
  CGFloat pointScaleFactor = layoutContext.pointScaleFactor;
  // measureContent passes Yoga's width, layout() a frame whose two edges Yoga
  // rounded separately: within a pixel they are one layout, so the memo keeps its
  // width (Android's sameWidth).
  if (slotMeasurement_.valid && std::abs(maxWidth - slotMeasurement_.width) < 1 / pointScaleFactor) {
    maxWidth = slotMeasurement_.width;
  }
  NSWritingDirection resolvedLayoutDirection = layoutConstraints.layoutDirection == LayoutDirection::RightToLeft
                                                   ? NSWritingDirectionRightToLeft
                                                   : NSWritingDirectionLeftToRight;
  CGFloat fontScale = ENRMFontScaleForMeasurement(props.allowFontScaling, layoutContext);

  const auto componentViewRef = getStateData().getComponentViewRef();
  RCTInternalGenericWeakWrapper *weakWrapper = (RCTInternalGenericWeakWrapper *)unwrapManagedObject(componentViewRef);
  EnrichedMarkdown *view = weakWrapper ? (EnrichedMarkdown *)weakWrapper.object : nil;
  NSSet<NSNumber *> *wrappedCodeBlocks = props.enableCodeBlockWrapToggle ? view.wrappedCodeBlockIndices : nil;

  MeasurementCacheKey key = buildMeasurementCacheKey(props, maxWidth, fontScale, MarkdownFlavor::GitHub,
                                                     ENRMWrappedCodeBlocksFingerprint(wrappedCodeBlocks));
  if (slotMeasurementMatches(slots, key, receivedCounter, maxWidth, layoutContext, layoutConstraints.layoutDirection)) {
    return slotMeasurement_.size;
  }

  NSMutableSet<NSString *> *slotIds = [NSMutableSet setWithCapacity:slots.size()];
  for (const auto &slot : slots) {
    [slotIds addObject:@(slot.id.c_str())];
  }
  const std::vector<SlotChild> *slotsPtr = &slots;
  LayoutDirection layoutDirection = layoutConstraints.layoutDirection;
  ENRMBlockSlotMeasurer *measurer = [[ENRMBlockSlotMeasurer alloc]
      initWithSlotIds:slotIds
              measure:^CGFloat(NSString *slotId, CGFloat width) {
                std::string id(slotId.UTF8String ?: "");
                for (const auto &slot : *slotsPtr) {
                  if (slot.id != id) {
                    continue;
                  }
                  // Reserve the height layout() gives the child, so the next segment
                  // never overlaps it.
                  return ENRMSlotChildHeight(*slot.node, layoutContext, layoutDirection, width);
                }
                return 0;
              }];

  CGSize size = ENRMMeasureSegmentedMarkdownViewFree(props, maxWidth, fontScale, pointScaleFactor,
                                                     resolvedLayoutDirection, wrappedCodeBlocks, measurer);

  NSDictionary<NSString *, NSValue *> *frames = measurer.frames;
  std::vector<SlotFrame> slotFrames;
  slotFrames.reserve(slots.size());
  for (const auto &slot : slots) {
    NSValue *frame = frames[@(slot.id.c_str())];
    if (frame) {
      CGRect rect = frame.CGRectValue;
      slotFrames.push_back(
          {slot.id, (Float)rect.origin.x, (Float)rect.origin.y, (Float)rect.size.width, (Float)rect.size.height, true});
    } else {
      slotFrames.push_back({slot.id, 0, 0, 0, 0, false});
    }
  }
  slotMeasurement_ =
      SlotMeasurement{true, true, std::move(key), receivedCounter, maxWidth, size, std::move(slotFrames)};
  return size;
}

Size EnrichedMarkdownShadowNode::measureContent(const LayoutContext &layoutContext,
                                                const LayoutConstraints &layoutConstraints) const
{
  const auto propsHandle = std::static_pointer_cast<const EnrichedMarkdownProps>(this->getProps());
  const auto &typedProps = *propsHandle;
  const int receivedCounter = getStateData().getHeightRecalculationCounter();
  const EnrichedMarkdownProps *props = propsHandle.get();
  CGFloat pointScaleFactor = layoutContext.pointScaleFactor;
  NSWritingDirection resolvedLayoutDirection = layoutConstraints.layoutDirection == LayoutDirection::RightToLeft
                                                   ? NSWritingDirectionRightToLeft
                                                   : NSWritingDirectionLeftToRight;

  const auto slots = slotChildren();
  if (!slots.empty()) {
    CGSize size = measureWithSlots(slots, layoutContext, layoutConstraints, layoutConstraints.maximumSize.width);
    return ENRMClampMeasuredSize(size, layoutConstraints);
  }
  slotMeasurement_ = SlotMeasurement{};

  // Wrapped code blocks are view state, not props, so they join the cache key by fingerprint.
  const auto componentViewRef = getStateData().getComponentViewRef();
  RCTInternalGenericWeakWrapper *weakWrapper = (RCTInternalGenericWeakWrapper *)unwrapManagedObject(componentViewRef);
  EnrichedMarkdown *view = weakWrapper ? (EnrichedMarkdown *)weakWrapper.object : nil;
  NSSet<NSNumber *> *wrappedCodeBlocks = typedProps.enableCodeBlockWrapToggle ? view.wrappedCodeBlockIndices : nil;

  return ENRMMeasureMarkdownContent<EnrichedMarkdownProps, EnrichedMarkdown>(
      typedProps, componentViewRef, receivedCounter, lastExactMeasurementCounter_, lastExactMeasurementSize_,
      MarkdownFlavor::GitHub, layoutContext, layoutConstraints,
      ^(EnrichedMarkdown *measuredView, CGFloat maxWidth, CGFloat fontScale) {
        return ENRMMeasureSegmentedMarkdownViewFree(*props, maxWidth, fontScale, pointScaleFactor,
                                                    resolvedLayoutDirection, wrappedCodeBlocks);
      },
      ENRMWrappedCodeBlocksFingerprint(wrappedCodeBlocks));
}

void EnrichedMarkdownShadowNode::layout(LayoutContext layoutContext)
{
  ensureUnsealed();

  const auto slots = slotChildren();
  const auto &state = getStateData();
  if (slots.empty()) {
    // The last slot child went away: tell the view so it stops reserving space.
    if (!state.getSlotPlacements().empty()) {
      setStateData(EnrichedMarkdownState(state.getHeightRecalculationCounter(), state.getComponentViewRef(), {}));
    }
    return;
  }

  auto layoutMetrics = getLayoutMetrics();
  auto contentFrame = layoutMetrics.getContentFrame();
  LayoutConstraints layoutConstraints{.minimumSize = contentFrame.size,
                                      .maximumSize = contentFrame.size,
                                      .layoutDirection = layoutMetrics.layoutDirection};

  // Yoga may have skipped measureContent (exact size known) after the document,
  // the height counter, the width or the children changed: the memoized measure
  // checks every input and returns at once when none did.
  measureWithSlots(slots, layoutContext, layoutConstraints, contentFrame.size.width);

  auto hostShadowNode = static_cast<EnrichedMarkdownShadowNode *>(this);
  auto hostOwningShadowNode = std::shared_ptr<ShadowNode>{};

  for (size_t i = 0; i < slots.size(); i++) {
    const auto &slot = slots[i];
    const SlotFrame &frame = slotMeasurement_.frames[i];

    auto clonedShadowNode = std::shared_ptr<ShadowNode>{};
    hostOwningShadowNode = hostShadowNode->cloneTree(slot.node->getFamily(), [&](const ShadowNode &oldShadowNode) {
      clonedShadowNode = oldShadowNode.clone({});
      return clonedShadowNode;
    });
    hostShadowNode = static_cast<EnrichedMarkdownShadowNode *>(hostOwningShadowNode.get());
    auto &layoutableShadowNode = static_cast<LayoutableShadowNode &>(*clonedShadowNode);

    if (!frame.placed) {
      layoutableShadowNode.setLayoutMetrics(LayoutMetrics{.frame = {}, .displayType = DisplayType::None});
      continue;
    }

    // The height is already on the pixel grid (rounding it up again adds a pixel
    // of float error); the width rounds up so the child keeps its measured width.
    auto slotSize = Size{roundToPixel<&ceil>(frame.width, layoutMetrics.pointScaleFactor),
                         roundToPixel<&round>(frame.height, layoutMetrics.pointScaleFactor)};
    auto slotOrigin = roundToPixel<&round>(Point{contentFrame.origin.x + frame.x, contentFrame.origin.y + frame.y},
                                           layoutMetrics.pointScaleFactor);
    auto slotConstraints = LayoutConstraints{slotSize, slotSize, layoutMetrics.layoutDirection};

    layoutableShadowNode.layoutTree(layoutContext, slotConstraints);

    auto slotLayoutMetrics = layoutableShadowNode.getLayoutMetrics();
    slotLayoutMetrics.frame.origin = slotOrigin;
    layoutableShadowNode.setLayoutMetrics(slotLayoutMetrics);
  }

  if (hostShadowNode != this) {
    this->children_ = static_cast<const EnrichedMarkdownShadowNode *>(hostShadowNode)->children_;
  }

  auto placements = slotPlacements();
  if (state.getSlotPlacements() != placements) {
    setStateData(EnrichedMarkdownState(state.getHeightRecalculationCounter(), state.getComponentViewRef(),
                                       std::move(placements)));
  }
}

} // namespace facebook::react
