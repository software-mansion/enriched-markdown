#pragma once
#include "ENRMMarkdownStreams.h"
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

  Props::Shared cloneProps(const PropsParserContext &context, const Props::Shared &props,
                           RawProps rawProps) const override {
    return ENRMResolveStreamedMarkdown<EnrichedMarkdownProps>(
        props, ConcreteComponentDescriptor::cloneProps(context, props, std::move(rawProps)));
  }
};

} // namespace facebook::react
