#include "MarkdownContainerMeasurementManager.h"

#include <fbjni/fbjni.h>
#include <react/jni/ReadableNativeMap.h>
#include <react/renderer/core/conversions.h>

using namespace facebook::jni;

namespace facebook::react {

Size MarkdownContainerMeasurementManager::measure(SurfaceId surfaceId, int viewTag, const std::string &markdown,
                                                  const MarkdownMeasureKeys &keys,
                                                  const std::vector<std::string> &blockSlotIds,
                                                  LayoutConstraints layoutConstraints) const {
  const jni::global_ref<jobject> &fabricUIManager = contextContainer_->at<jni::global_ref<jobject>>("FabricUIManager");

  static const auto measure =
      facebook::jni::findClassStatic("com/facebook/react/fabric/FabricUIManager")
          ->getMethod<jlong(jint, jstring, ReadableMap::javaobject, ReadableMap::javaobject, ReadableMap::javaobject,
                            jfloat, jfloat, jfloat, jfloat)>("measure");

  auto minimumSize = layoutConstraints.minimumSize;
  auto maximumSize = layoutConstraints.maximumSize;

  local_ref<JString> componentName = make_jstring("EnrichedMarkdown");

  // Prepare extraData map with viewTag and the slot children to measure
  folly::dynamic extraData = folly::dynamic::object();
  extraData["viewTag"] = viewTag;
  folly::dynamic slotIds = folly::dynamic::array();
  for (const auto &id : blockSlotIds) {
    slotIds.push_back(id);
  }
  extraData["blockSlotIds"] = std::move(slotIds);
  local_ref<ReadableNativeMap::javaobject> extraDataRNM = ReadableNativeMap::newObjectCxxArgs(extraData);
  local_ref<ReadableMap::javaobject> extraDataRM =
      make_local(reinterpret_cast<ReadableMap::javaobject>(extraDataRNM.get()));

  // The keys stand in for the props; Kotlin pulls the markdown or config from the session when it
  // doesn't have them (MarkdownMeasureSession).
  local_ref<ReadableNativeMap::javaobject> propsRNM = ReadableNativeMap::newObjectCxxArgs(keys.toDynamic());
  local_ref<ReadableMap::javaobject> propsRM = make_local(reinterpret_cast<ReadableMap::javaobject>(propsRNM.get()));

  MarkdownMeasureSession session(markdown, *keys.config);
  MarkdownMeasureSession::Scope scope(&session);
  auto measurement = yogaMeassureToSize(measure(fabricUIManager, surfaceId, componentName.get(), extraDataRM.get(),
                                                propsRM.get(), nullptr, minimumSize.width, maximumSize.width,
                                                minimumSize.height, maximumSize.height));

  return measurement;
}

} // namespace facebook::react
