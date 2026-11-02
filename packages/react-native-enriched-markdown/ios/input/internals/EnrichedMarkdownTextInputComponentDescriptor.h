#pragma once
#include "ENRMReactHeaders.h"
#include "EnrichedMarkdownTextInputShadowNode.h"

namespace facebook::react {

class EnrichedMarkdownTextInputComponentDescriptor final
    : public ConcreteComponentDescriptor<EnrichedMarkdownTextInputShadowNode> {
public:
  using ConcreteComponentDescriptor::ConcreteComponentDescriptor;

  void adopt(ShadowNode &shadowNode) const override {
    react_native_assert(dynamic_cast<EnrichedMarkdownTextInputShadowNode *>(&shadowNode));
    ConcreteComponentDescriptor::adopt(shadowNode);
  }
};

} // namespace facebook::react
