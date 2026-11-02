#pragma once
#include "ENRMReactHeaders.h"
#include "EnrichedMarkdownTextInputState.h"
#include <ReactNativeEnrichedMarkdown/EventEmitters.h>
#include <ReactNativeEnrichedMarkdown/Props.h>

namespace facebook::react {

JSI_EXPORT extern const char EnrichedMarkdownTextInputComponentName[];

class EnrichedMarkdownTextInputShadowNode
    : public ConcreteViewShadowNode<EnrichedMarkdownTextInputComponentName, EnrichedMarkdownTextInputProps,
                                    EnrichedMarkdownTextInputEventEmitter, EnrichedMarkdownTextInputState> {
public:
  using ConcreteViewShadowNode::ConcreteViewShadowNode;

  EnrichedMarkdownTextInputShadowNode(const ShadowNodeFragment &fragment, const ShadowNodeFamily::Shared &family,
                                      ShadowNodeTraits traits);

  EnrichedMarkdownTextInputShadowNode(const ShadowNode &sourceShadowNode, const ShadowNodeFragment &fragment);

  void dirtyLayoutIfNeeded();

  Size measureContent(const LayoutContext &layoutContext, const LayoutConstraints &layoutConstraints) const override;

  static ShadowNodeTraits BaseTraits()
  {
    auto traits = ConcreteViewShadowNode::BaseTraits();
    traits.set(ShadowNodeTraits::Trait::LeafYogaNode);
    traits.set(ShadowNodeTraits::Trait::MeasurableYogaNode);
    return traits;
  }

private:
  int localHeightRecalculationCounter_{0};
  id setupMockInputView_(CGFloat width) const;
};

} // namespace facebook::react
