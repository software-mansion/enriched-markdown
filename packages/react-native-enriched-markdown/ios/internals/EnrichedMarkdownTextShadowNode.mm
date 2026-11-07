#import "EnrichedMarkdownTextShadowNode.h"
#import "ENRMViewFreeMeasurement.h"
#import "EnrichedMarkdownText.h"
#import "ShadowMeasurementUtils.h"
#import <yoga/Yoga.h>

namespace facebook::react {

extern const char EnrichedMarkdownTextComponentName[] = "EnrichedMarkdownText";

EnrichedMarkdownTextShadowNode::EnrichedMarkdownTextShadowNode(const ShadowNodeFragment &fragment,
                                                               const ShadowNodeFamily::Shared &family,
                                                               ShadowNodeTraits traits)
    : ConcreteViewShadowNode(fragment, family, traits)
{
}

EnrichedMarkdownTextShadowNode::EnrichedMarkdownTextShadowNode(const ShadowNode &sourceShadowNode,
                                                               const ShadowNodeFragment &fragment)
    : ConcreteViewShadowNode(sourceShadowNode, fragment),
      localHeightRecalculationCounter_(
          static_cast<const EnrichedMarkdownTextShadowNode &>(sourceShadowNode).localHeightRecalculationCounter_),
      lastExactMeasurementCounter_(
          static_cast<const EnrichedMarkdownTextShadowNode &>(sourceShadowNode).lastExactMeasurementCounter_),
      lastExactMeasurementSize_(
          static_cast<const EnrichedMarkdownTextShadowNode &>(sourceShadowNode).lastExactMeasurementSize_)
{
  const auto &oldProps = *std::static_pointer_cast<const EnrichedMarkdownTextProps>(sourceShadowNode.getProps());
  const auto &newProps = *std::static_pointer_cast<const EnrichedMarkdownTextProps>(this->getProps());

  if (newProps.streamingAnimation && ENRMPropsNeedExactStreamingMeasurement(oldProps, newProps)) {
    lastExactMeasurementCounter_ = -1;
  }

  dirtyLayoutIfNeeded();
}

void EnrichedMarkdownTextShadowNode::dirtyLayoutIfNeeded()
{
  const auto state = this->getStateData();
  const int receivedCounter = state.getHeightRecalculationCounter();

  if (receivedCounter > localHeightRecalculationCounter_) {
    localHeightRecalculationCounter_ = receivedCounter;
    YGNodeMarkDirty(&yogaNode_);
  }
}

Size EnrichedMarkdownTextShadowNode::measureContent(const LayoutContext &layoutContext,
                                                    const LayoutConstraints &layoutConstraints) const
{
  const auto propsHandle = std::static_pointer_cast<const EnrichedMarkdownTextProps>(this->getProps());
  const int receivedCounter = getStateData().getHeightRecalculationCounter();
  const EnrichedMarkdownTextProps *props = propsHandle.get();
  CGFloat pointScaleFactor = layoutContext.pointScaleFactor;
  NSWritingDirection resolvedLayoutDirection = layoutConstraints.layoutDirection == LayoutDirection::RightToLeft
                                                   ? NSWritingDirectionRightToLeft
                                                   : NSWritingDirectionLeftToRight;

  return ENRMMeasureMarkdownContent<EnrichedMarkdownTextProps, EnrichedMarkdownText>(
      propsHandle, getStateData().getComponentViewRef(), receivedCounter, lastExactMeasurementCounter_,
      lastExactMeasurementSize_, MarkdownFlavor::CommonMark, layoutContext, layoutConstraints, resolvedLayoutDirection,
      ^id(CGFloat fontScale) {
        return ENRMRenderMarkdownViewFree(*props, ENRMStyleConfigFromProps(*props, fontScale), resolvedLayoutDirection);
      },
      ^(EnrichedMarkdownText *view, CGFloat maxWidth, CGFloat fontScale, id rendered) {
        return ENRMMeasureMarkdownViewFree(*props, maxWidth, fontScale, pointScaleFactor, resolvedLayoutDirection,
                                           rendered);
      });
}

} // namespace facebook::react
