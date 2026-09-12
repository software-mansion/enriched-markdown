#pragma once

#include "MD4CParser.hpp"

#include <fbjni/fbjni.h>

namespace enriched::jni {

struct JNodeType : facebook::jni::JavaClass<JNodeType> {
  static constexpr auto kJavaDescriptor = "Lcom/swmansion/enriched/markdown/parser/MarkdownASTNode$NodeType;";

  static facebook::jni::local_ref<JNodeType> fromOrdinal(jint ordinal);
};

struct JMarkdownASTNode : facebook::jni::JavaClass<JMarkdownASTNode> {
  static constexpr auto kJavaDescriptor = "Lcom/swmansion/enriched/markdown/parser/MarkdownASTNode;";

  static facebook::jni::local_ref<JMarkdownASTNode>
  create(facebook::jni::alias_ref<JNodeType> type, facebook::jni::alias_ref<facebook::jni::JString> content,
         facebook::jni::alias_ref<facebook::jni::JMap<facebook::jni::JString, facebook::jni::JString>> attributes,
         facebook::jni::alias_ref<facebook::jni::JList<JMarkdownASTNode>> children);
};

struct JMd4cFlags : facebook::jni::JavaClass<JMd4cFlags> {
  static constexpr auto kJavaDescriptor = "Lcom/swmansion/enriched/markdown/parser/Md4cFlags;";

  Markdown::Md4cFlags toCppFlags() const;
};

struct JParser : facebook::jni::JavaClass<JParser> {
  static constexpr auto kJavaDescriptor = "Lcom/swmansion/enriched/markdown/parser/Parser;";

  static facebook::jni::local_ref<JMarkdownASTNode>
  nativeParseMarkdown(facebook::jni::alias_ref<facebook::jni::JClass> clazz,
                      facebook::jni::alias_ref<facebook::jni::JString> markdown,
                      facebook::jni::alias_ref<JMd4cFlags> flags);

  static void registerNatives();
};

} // namespace enriched::jni
