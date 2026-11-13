#pragma once

#include <folly/dynamic.h>
#include <react/renderer/components/EnrichedMarkdownTextSpec/Props.h>
#include <react/renderer/core/propsConversions.h>

namespace facebook::react {

#ifdef RN_SERIALIZABLE_STATE
// The streaming options that change what is laid out: the modes decide what the streaming filter
// withholds, smooth pacing how much the view shows. The animation draws over the same layout, so
// it stays out and changing it measures nothing again.
template <typename StreamingConfig>
folly::dynamic streamingLayoutConfig(const StreamingConfig &config) {
  return folly::dynamic::object("tableMode", config.tableMode)("codeBlockMode", config.codeBlockMode)(
      "mediaMode", config.mediaMode)("smooth", config.smooth);
}

// Every prop besides the markdown that measurement needs to lay the document out as the view
// does (MeasureConfig in Kotlin). A prop missing here measures with its default: the measured
// height and the rendered one disagree.
inline folly::dynamic measureLayoutConfig(const EnrichedMarkdownTextProps &props) {
  folly::dynamic serializedProps = folly::dynamic::object();
  // Always false here (GFM goes to EnrichedMarkdown), but the view parses with it.
  serializedProps["isGFM"] = props.isGFM;
  serializedProps["markdownStyle"] = toDynamic(props.markdownStyle);
  serializedProps["md4cFlags"] = toDynamic(props.md4cFlags);
  serializedProps["allowFontScaling"] = props.allowFontScaling;
  serializedProps["maxFontSizeMultiplier"] = props.maxFontSizeMultiplier;
  serializedProps["allowTrailingMargin"] = props.allowTrailingMargin;
  serializedProps["textBreakStrategy"] = props.textBreakStrategy;
  serializedProps["streaming"] = props.streaming;
  serializedProps["streamingConfig"] = streamingLayoutConfig(props.streamingConfig);
  serializedProps["numberOfLines"] = props.numberOfLines;
  serializedProps["ellipsizeMode"] = props.ellipsizeMode;

  folly::dynamic imageRequestHeaders = folly::dynamic::array();
  for (const auto &header : props.imageRequestHeaders) {
    imageRequestHeaders.push_back(toDynamic(header));
  }
  serializedProps["imageRequestHeaders"] = std::move(imageRequestHeaders);

  // Pill labels change text width, so measurement needs the same content the view renders.
  folly::dynamic linkPillContent = folly::dynamic::array();
  for (const auto &content : props.linkPillContent) {
    linkPillContent.push_back(toDynamic(content));
  }
  serializedProps["linkPillContent"] = std::move(linkPillContent);

  // Recognition changes line wrapping, so measurement must parse with the view's patterns.
  serializedProps["linkRecognition"] = toDynamic(props.linkRecognition);

  return serializedProps;
}

inline folly::dynamic measureLayoutConfig(const EnrichedMarkdownProps &props) {
  folly::dynamic serializedProps = folly::dynamic::object();
  serializedProps["markdownStyle"] = toDynamic(props.markdownStyle);
  serializedProps["md4cFlags"] = toDynamic(props.md4cFlags);
  serializedProps["allowFontScaling"] = props.allowFontScaling;
  serializedProps["maxFontSizeMultiplier"] = props.maxFontSizeMultiplier;
  serializedProps["allowTrailingMargin"] = props.allowTrailingMargin;
  serializedProps["textBreakStrategy"] = props.textBreakStrategy;
  serializedProps["streaming"] = props.streaming;
  serializedProps["streamingConfig"] = streamingLayoutConfig(props.streamingConfig);
  // A `<video>` block only exists under GFM; CommonMark measures it as text.
  serializedProps["isGFM"] = props.isGFM;
  // Wrapped code blocks measure at the block width; the indexes live in MeasurementStore.
  serializedProps["enableCodeBlockWrapToggle"] = props.enableCodeBlockWrapToggle;

  folly::dynamic imageRequestHeaders = folly::dynamic::array();
  for (const auto &header : props.imageRequestHeaders) {
    imageRequestHeaders.push_back(toDynamic(header));
  }
  serializedProps["imageRequestHeaders"] = std::move(imageRequestHeaders);

  // Image source overrides change which image loads, and so its measured box.
  folly::dynamic imageSources = folly::dynamic::array();
  for (const auto &source : props.imageSources) {
    imageSources.push_back(toDynamic(source));
  }
  serializedProps["imageSources"] = std::move(imageSources);

  // Pill labels change text width, so measurement needs the same content the view renders.
  folly::dynamic linkPillContent = folly::dynamic::array();
  for (const auto &content : props.linkPillContent) {
    linkPillContent.push_back(toDynamic(content));
  }
  serializedProps["linkPillContent"] = std::move(linkPillContent);

  // Recognition changes line wrapping, so measurement must parse with the view's patterns.
  serializedProps["linkRecognition"] = toDynamic(props.linkRecognition);

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
