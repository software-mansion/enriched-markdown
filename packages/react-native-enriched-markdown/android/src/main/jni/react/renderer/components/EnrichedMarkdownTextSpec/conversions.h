#pragma once

#include <folly/dynamic.h>
#include <react/renderer/components/EnrichedMarkdownTextSpec/Props.h>
#include <react/renderer/core/propsConversions.h>

namespace facebook::react {

#ifdef RN_SERIALIZABLE_STATE
inline folly::dynamic toDynamic(const EnrichedMarkdownTextProps &props) {
  folly::dynamic serializedProps = folly::dynamic::object();
  serializedProps["markdown"] = props.markdown;
  serializedProps["markdownStyle"] = toDynamic(props.markdownStyle);
  serializedProps["md4cFlags"] = toDynamic(props.md4cFlags);
  serializedProps["allowFontScaling"] = props.allowFontScaling;
  serializedProps["maxFontSizeMultiplier"] = props.maxFontSizeMultiplier;
  serializedProps["allowTrailingMargin"] = props.allowTrailingMargin;
  serializedProps["streamingAnimation"] = props.streamingAnimation;

  folly::dynamic imageRequestHeaders = folly::dynamic::array();
  for (const auto &header : props.imageRequestHeaders) {
    imageRequestHeaders.push_back(toDynamic(header));
  }
  serializedProps["imageRequestHeaders"] = std::move(imageRequestHeaders);

  return serializedProps;
}

inline folly::dynamic toDynamic(const EnrichedMarkdownProps &props) {
  folly::dynamic serializedProps = folly::dynamic::object();
  serializedProps["markdown"] = props.markdown;
  serializedProps["markdownStyle"] = toDynamic(props.markdownStyle);
  serializedProps["md4cFlags"] = toDynamic(props.md4cFlags);
  serializedProps["allowFontScaling"] = props.allowFontScaling;
  serializedProps["maxFontSizeMultiplier"] = props.maxFontSizeMultiplier;
  serializedProps["allowTrailingMargin"] = props.allowTrailingMargin;
  serializedProps["streamingAnimation"] = props.streamingAnimation;

  folly::dynamic imageRequestHeaders = folly::dynamic::array();
  for (const auto &header : props.imageRequestHeaders) {
    imageRequestHeaders.push_back(toDynamic(header));
  }
  serializedProps["imageRequestHeaders"] = std::move(imageRequestHeaders);

  return serializedProps;
}

inline folly::dynamic toDynamic(const EnrichedMarkdownTextInputProps &props) {
  folly::dynamic serializedProps = folly::dynamic::object();
  serializedProps["defaultValue"] = props.defaultValue;
  serializedProps["placeholder"] = props.placeholder;
  serializedProps["fontSize"] = props.fontSize;
  serializedProps["fontWeight"] = props.fontWeight;
  serializedProps["fontFamily"] = props.fontFamily;
  serializedProps["lineHeight"] = props.lineHeight;

  return serializedProps;
}
#endif

} // namespace facebook::react
