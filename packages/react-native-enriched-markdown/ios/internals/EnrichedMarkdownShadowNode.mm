#import "EnrichedMarkdownShadowNode.h"
#import "ENRMViewFreeMeasurement.h"
#import "EnrichedMarkdown.h"
#import "ShadowMeasurementUtils.h"
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
          static_cast<const EnrichedMarkdownShadowNode &>(sourceShadowNode).lastExactMeasurementSize_)
{
  const auto &oldProps = *std::static_pointer_cast<const EnrichedMarkdownProps>(sourceShadowNode.getProps());
  const auto &newProps = *std::static_pointer_cast<const EnrichedMarkdownProps>(this->getProps());

  if (newProps.streamingAnimation && ENRMPropsNeedExactStreamingMeasurement(oldProps, newProps)) {
    lastExactMeasurementCounter_ = -1;
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

} // namespace facebook::react
