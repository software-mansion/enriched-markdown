#pragma once

#include "ENRMReactHeaders.h"
#include "MarkdownTextMeasurementManager.h"
#include "MarkdownTextState.h"

#include <react/renderer/components/EnrichedMarkdownTextSpec/EventEmitters.h>
#include <react/renderer/components/EnrichedMarkdownTextSpec/Props.h>

namespace facebook::react {

JSI_EXPORT extern const char MarkdownTextComponentName[];

/*
 * `ShadowNode` for <EnrichedMarkdownText> component.
 */
class MarkdownTextShadowNode final
    : public ConcreteViewShadowNode<MarkdownTextComponentName, EnrichedMarkdownTextProps,
                                    EnrichedMarkdownTextEventEmitter, MarkdownTextState> {
public:
  using ConcreteViewShadowNode::ConcreteViewShadowNode;

  MarkdownTextShadowNode(ShadowNode const &sourceShadowNode, ShadowNodeFragment const &fragment)
      : ConcreteViewShadowNode(sourceShadowNode, fragment),
        measureKeys_(static_cast<const MarkdownTextShadowNode &>(sourceShadowNode).measureKeys_) {
    forceHeightRecalculationCounter_ =
        static_cast<const MarkdownTextShadowNode &>(sourceShadowNode).forceHeightRecalculationCounter_;
    dirtyLayoutIfNeeded();
  }

  static ShadowNodeTraits BaseTraits() {
    auto traits = ConcreteViewShadowNode::BaseTraits();
    traits.set(ShadowNodeTraits::Trait::LeafYogaNode);
    traits.set(ShadowNodeTraits::Trait::MeasurableYogaNode);
    return traits;
  }

  // Associates a shared `MarkdownTextMeasurementManager` with the node.
  void setMeasurementsManager(const std::shared_ptr<MarkdownTextMeasurementManager> &measurementsManager);

  void dirtyLayoutIfNeeded();

  Size measureContent(const LayoutContext &layoutContext, const LayoutConstraints &layoutConstraints) const override;

protected:
  bool shouldNewRevisionDirtyMeasurement(const ShadowNode &sourceShadowNode,
                                         const ShadowNodeFragment &fragment) const override;

private:
  int forceHeightRecalculationCounter_{0};
  std::shared_ptr<MarkdownTextMeasurementManager> measurementsManager_;
  // The keys measurement sends for the current props, brought up to them first.
  const MarkdownMeasureKeys &measureKeys() const;

  mutable MarkdownMeasureKeys measureKeys_;
};

} // namespace facebook::react
