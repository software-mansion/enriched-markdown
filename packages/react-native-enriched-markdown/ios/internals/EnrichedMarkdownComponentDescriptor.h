#pragma once
#include "ENRMReactHeaders.h"
#include "EnrichedMarkdownShadowNode.h"

namespace facebook::react {

class EnrichedMarkdownComponentDescriptor final : public ConcreteComponentDescriptor<EnrichedMarkdownShadowNode> {
public:
  using ConcreteComponentDescriptor::ConcreteComponentDescriptor;

  void adopt(ShadowNode &shadowNode) const override {
    react_native_assert(dynamic_cast<EnrichedMarkdownShadowNode *>(&shadowNode));
    ConcreteComponentDescriptor::adopt(shadowNode);
  }
};

} // namespace facebook::react
