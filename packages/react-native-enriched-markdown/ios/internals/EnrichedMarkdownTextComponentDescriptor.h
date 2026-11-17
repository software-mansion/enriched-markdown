#pragma once
#include "ENRMMarkdownStreams.h"
#include "ENRMReactHeaders.h"
#include "EnrichedMarkdownTextShadowNode.h"

namespace facebook::react {

class EnrichedMarkdownTextComponentDescriptor final
    : public ConcreteComponentDescriptor<EnrichedMarkdownTextShadowNode> {
public:
  using ConcreteComponentDescriptor::ConcreteComponentDescriptor;

  void adopt(ShadowNode &shadowNode) const override {
    react_native_assert(dynamic_cast<EnrichedMarkdownTextShadowNode *>(&shadowNode));
    ConcreteComponentDescriptor::adopt(shadowNode);
  }

  Props::Shared cloneProps(const PropsParserContext &context, const Props::Shared &props,
                           RawProps rawProps) const override {
    return ENRMResolveStreamedMarkdown<EnrichedMarkdownTextProps>(
        props, ConcreteComponentDescriptor::cloneProps(context, props, std::move(rawProps)));
  }
};

} // namespace facebook::react
