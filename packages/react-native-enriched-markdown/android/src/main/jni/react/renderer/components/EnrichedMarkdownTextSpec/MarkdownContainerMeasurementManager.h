#pragma once

#include <react/renderer/components/EnrichedMarkdownTextSpec/Props.h>
#include <react/renderer/core/LayoutConstraints.h>
#include <react/utils/ContextContainer.h>
#include <string>
#include <vector>

namespace facebook::react {

class MarkdownContainerMeasurementManager {
public:
  MarkdownContainerMeasurementManager(const std::shared_ptr<const ContextContainer> &contextContainer)
      : contextContainer_(contextContainer) {}

  // blockSlotIds are the host's slot children; the Kotlin walk measures each one
  // through the current BlockSlotMeasureSession.
  Size measure(SurfaceId surfaceId, int viewTag, const EnrichedMarkdownProps &props,
               const std::vector<std::string> &blockSlotIds, LayoutConstraints layoutConstraints) const;

private:
  const std::shared_ptr<const ContextContainer> contextContainer_;
};

} // namespace facebook::react
