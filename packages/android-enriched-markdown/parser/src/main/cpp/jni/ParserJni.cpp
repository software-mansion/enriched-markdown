#include "JavaTypes.h"

#include "MD4CParser.hpp"

#include <android/log.h>
#include <fbjni/fbjni.h>

#include <memory>
#include <string>

using namespace facebook::jni;
using namespace Markdown;

namespace enriched::jni {

namespace {

#define ENRICHEDMARKDOWN_LOG_TAG "EnrichedMarkdownJNI"
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, ENRICHEDMARKDOWN_LOG_TAG, __VA_ARGS__)

static_assert(static_cast<int>(NodeType::Highlight) == 29,
              "NodeType enum must stay in sync with Kotlin MarkdownASTNode.NodeType");
static_assert(static_cast<int>(NodeType::SoftBreak) == 30,
              "NodeType enum must stay in sync with Kotlin MarkdownASTNode.NodeType");

local_ref<JMarkdownASTNode> createJavaNode(const std::shared_ptr<MarkdownASTNode> &node) {
  if (!node) {
    return nullptr;
  }

  auto nodeType = JNodeType::fromOrdinal(static_cast<jint>(node->type));
  auto content = make_jstring(node->content);

  auto attributes = JHashMap<JString, JString>::create();
  for (const auto &pair : node->attributes) {
    attributes->put(make_jstring(pair.first), make_jstring(pair.second));
  }

  auto children = JArrayList<JMarkdownASTNode>::create();
  for (const auto &child : node->children) {
    auto childNode = createJavaNode(child);
    if (childNode) {
      children->add(childNode);
    }
  }

  return JMarkdownASTNode::create(nodeType, content, attributes, children);
}

} // namespace

local_ref<JNodeType> JNodeType::fromOrdinal(jint ordinal) {
  static const auto valuesMethod = javaClassStatic()->getStaticMethod<local_ref<JArrayClass<JNodeType>>()>("values");
  auto values = valuesMethod(javaClassStatic());
  return values->getElement(ordinal);
}

local_ref<JMarkdownASTNode> JMarkdownASTNode::create(alias_ref<JNodeType> type, alias_ref<JString> content,
                                                     alias_ref<JMap<JString, JString>> attributes,
                                                     alias_ref<JList<JMarkdownASTNode>> children) {
  return newInstance(type, content, attributes, children);
}

Md4cFlags JMd4cFlags::toCppFlags() const {
  static const auto underlineField = javaClassStatic()->getField<jboolean>("underline");
  static const auto latexMathField = javaClassStatic()->getField<jboolean>("latexMath");
  static const auto superscriptField = javaClassStatic()->getField<jboolean>("superscript");
  static const auto subscriptField = javaClassStatic()->getField<jboolean>("subscript");
  static const auto highlightField = javaClassStatic()->getField<jboolean>("highlight");
  static const auto permissiveAutolinksField = javaClassStatic()->getField<jboolean>("permissiveAutolinks");
  static const auto hardSoftBreaksField = javaClassStatic()->getField<jboolean>("hardSoftBreaks");

  Md4cFlags flags;
  flags.underline = getFieldValue(underlineField) == JNI_TRUE;
  flags.latexMath = getFieldValue(latexMathField) == JNI_TRUE;
  flags.superscript = getFieldValue(superscriptField) == JNI_TRUE;
  flags.subscript = getFieldValue(subscriptField) == JNI_TRUE;
  flags.highlight = getFieldValue(highlightField) == JNI_TRUE;
  flags.permissiveAutolinks = getFieldValue(permissiveAutolinksField) == JNI_TRUE;
  flags.hardSoftBreaks = getFieldValue(hardSoftBreaksField) == JNI_TRUE;
  return flags;
}

local_ref<JMarkdownASTNode> JParser::nativeParseMarkdown(alias_ref<JClass> /* clazz */, alias_ref<JString> markdown,
                                                         alias_ref<JMd4cFlags> flags) {
  if (!markdown) {
    LOGE("Markdown string is null");
    return nullptr;
  }

  try {
    const auto markdownStr = markdown->toStdString();
    Md4cFlags md4cFlags = flags ? flags->toCppFlags() : Md4cFlags{};

    MD4CParser parser;
    auto ast = parser.parse(markdownStr, md4cFlags);

    if (!ast) {
      LOGE("Parser returned null AST");
      return nullptr;
    }

    auto javaNode = createJavaNode(ast);
    if (!javaNode) {
      LOGE("Failed to create Java node from AST");
    }
    return javaNode;
  } catch (const std::exception &e) {
    LOGE("Exception during parsing: %s", e.what());
    return nullptr;
  } catch (...) {
    LOGE("Unknown exception during parsing");
    return nullptr;
  }
}

void JParser::registerNatives() {
  javaClassStatic()->registerNatives({
      makeNativeMethod("nativeParseMarkdown", JParser::nativeParseMarkdown),
  });
}

} // namespace enriched::jni

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *vm, void *) {
  return facebook::jni::initialize(vm, [] { enriched::jni::JParser::registerNatives(); });
}
