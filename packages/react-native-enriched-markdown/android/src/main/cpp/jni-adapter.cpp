#include "AstOverlay.hpp"
#include "BlockSlotMeasureSession.h"
#include "CodeBlockHighlighter.hpp"
#include "CodeBlockLanguages.hpp"
#include "DocumentStore.hpp"
#include "LatexSpeech.hpp"
#include "StreamingEffects.hpp"
#include "StreamingPacer.hpp"
#include "TextLinkRecognizer.hpp"
#include "Utf16.hpp"
#include <algorithm>
#include <android/log.h>
#include <jni.h>
#include <string>
#include <string_view>
#include <unordered_set>
#include <vector>

using namespace Markdown;

#define ENRICHEDMARKDOWN_LOG_TAG "EnrichedMarkdownJNI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, ENRICHEDMARKDOWN_LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, ENRICHEDMARKDOWN_LOG_TAG, __VA_ARGS__)

// Helper function to convert C++ NodeType to Kotlin enum ordinal
static jint nodeTypeToJavaOrdinal(NodeType type) {
  switch (type) {
    case NodeType::Document:
      return 0;
    case NodeType::Paragraph:
      return 1;
    case NodeType::Text:
      return 2;
    case NodeType::Link:
      return 3;
    case NodeType::Heading:
      return 4;
    case NodeType::LineBreak:
      return 5;
    case NodeType::Strong:
      return 6;
    case NodeType::Emphasis:
      return 7;
    case NodeType::Strikethrough:
      return 8;
    case NodeType::Underline:
      return 9;
    case NodeType::Code:
      return 10;
    case NodeType::Image:
      return 11;
    case NodeType::Blockquote:
      return 12;
    case NodeType::UnorderedList:
      return 13;
    case NodeType::OrderedList:
      return 14;
    case NodeType::ListItem:
      return 15;
    case NodeType::CodeBlock:
      return 16;
    case NodeType::ThematicBreak:
      return 17;
    case NodeType::Table:
      return 18;
    case NodeType::TableHead:
      return 19;
    case NodeType::TableBody:
      return 20;
    case NodeType::TableRow:
      return 21;
    case NodeType::TableHeaderCell:
      return 22;
    case NodeType::TableCell:
      return 23;
    case NodeType::LatexMathInline:
      return 24;
    case NodeType::LatexMathDisplay:
      return 25;
    case NodeType::Spoiler:
      return 26;
    case NodeType::Superscript:
      return 27;
    case NodeType::Subscript:
      return 28;
    case NodeType::Highlight:
      return 29;
    case NodeType::SoftBreak:
      return 30;
    case NodeType::BlankLine:
      return 31;
    case NodeType::Admonition:
      return 32;
    case NodeType::Video:
      return 33;
    default:
      return 0;
  }
}

// Strings cross JNI as UTF-16 (NewString / GetStringRegion): modified UTF-8
// (GetStringUTFChars / NewStringUTF) encodes characters outside the BMP
// differently from the UTF-8 the JS block collector hashes, so ids would not
// match, and the text matchers' offsets count UTF-16 units anyway.
static jstring javaString(JNIEnv *env, std::string_view utf8) {
  std::u16string utf16 = toUtf16(utf8);
  return env->NewString(reinterpret_cast<const jchar *>(utf16.data()), static_cast<jsize>(utf16.size()));
}

static std::string utf8String(JNIEnv *env, jstring string) {
  if (!string)
    return {};
  std::u16string utf16(static_cast<size_t>(env->GetStringLength(string)), u'\0');
  env->GetStringRegion(string, 0, static_cast<jsize>(utf16.size()), reinterpret_cast<jchar *>(utf16.data()));
  return toUtf8(utf16);
}

namespace {

// Builds Kotlin MarkdownASTNode objects from the shared C++ tree, with the
// overlay's slot ids, image ids and recognized links applied on the way. The
// classes and methods are looked up once per conversion, not per node.
class JavaNodeFactory {
public:
  explicit JavaNodeFactory(JNIEnv *env) : env_(env) {
    ready_ = lookUp();
    if (!ready_) {
      LOGE("Failed to find the MarkdownASTNode classes");
      env_->ExceptionClear();
    }
  }

  ~JavaNodeFactory() {
    for (jobject ref : {(jobject)nodeClass_, (jobject)mapClass_, (jobject)listClass_, (jobject)nodeTypes_}) {
      if (ref)
        env_->DeleteLocalRef(ref);
    }
  }

  // Each node gets its own local frame, so a deep tree never runs out of local
  // references and only the returned node outlives the call.
  jobject create(const MarkdownASTNode &node, const AstOverlay &overlay) {
    if (!ready_ || env_->PushLocalFrame(16) != JNI_OK)
      return nullptr;
    jobject nodeType = env_->GetObjectArrayElement(nodeTypes_, nodeTypeToJavaOrdinal(node.type));
    jobject attributes = env_->NewObject(mapClass_, mapInit_, static_cast<jint>(node.attributes.size()));
    auto put = [&](std::string_view key, std::string_view value) {
      env_->CallObjectMethod(attributes, mapPut_, javaString(env_, key), javaString(env_, value));
    };
    for (const auto &[key, value] : node.attributes)
      put(key, value);
    overlay.forEachAttribute(node, [&](const char *key, const std::string &value) { put(key, value); });

    jobject children = env_->NewObject(listClass_, listInit_, static_cast<jint>(node.children.size()));
    overlay.forEachChild(node, [&](const std::shared_ptr<MarkdownASTNode> &child) {
      if (jobject javaChild = create(*child, overlay)) {
        env_->CallBooleanMethod(children, listAdd_, javaChild);
        env_->DeleteLocalRef(javaChild);
      }
    });

    jobject javaNode =
        env_->NewObject(nodeClass_, constructor_, nodeType, javaString(env_, node.content), attributes, children);
    if (env_->ExceptionCheck()) {
      env_->ExceptionDescribe();
      env_->ExceptionClear();
      env_->PopLocalFrame(nullptr);
      return nullptr;
    }
    return env_->PopLocalFrame(javaNode);
  }

private:
  bool lookUp() {
    nodeClass_ = env_->FindClass("com/swmansion/enriched/markdown/parser/MarkdownASTNode");
    if (!nodeClass_)
      return false;
    jclass nodeTypeClass = env_->FindClass("com/swmansion/enriched/markdown/parser/MarkdownASTNode$NodeType");
    if (!nodeTypeClass)
      return false;
    jmethodID values = env_->GetStaticMethodID(nodeTypeClass, "values",
                                               "()[Lcom/swmansion/enriched/markdown/parser/MarkdownASTNode$NodeType;");
    nodeTypes_ = values ? (jobjectArray)env_->CallStaticObjectMethod(nodeTypeClass, values) : nullptr;
    env_->DeleteLocalRef(nodeTypeClass);
    if (!nodeTypes_)
      return false;
    constructor_ = env_->GetMethodID(nodeClass_, "<init>",
                                     "(Lcom/swmansion/enriched/markdown/parser/MarkdownASTNode$NodeType;Ljava/"
                                     "lang/String;Ljava/util/Map;Ljava/util/List;)V");
    if (!constructor_)
      return false;
    mapClass_ = env_->FindClass("java/util/HashMap");
    if (!mapClass_)
      return false;
    mapInit_ = env_->GetMethodID(mapClass_, "<init>", "(I)V");
    mapPut_ = env_->GetMethodID(mapClass_, "put", "(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;");
    listClass_ = env_->FindClass("java/util/ArrayList");
    if (!mapInit_ || !mapPut_ || !listClass_)
      return false;
    listInit_ = env_->GetMethodID(listClass_, "<init>", "(I)V");
    listAdd_ = env_->GetMethodID(listClass_, "add", "(Ljava/lang/Object;)Z");
    return listInit_ && listAdd_;
  }

  JNIEnv *env_;
  jclass nodeClass_ = nullptr;
  jclass mapClass_ = nullptr;
  jclass listClass_ = nullptr;
  jobjectArray nodeTypes_ = nullptr;
  jmethodID constructor_ = nullptr;
  jmethodID mapInit_ = nullptr;
  jmethodID mapPut_ = nullptr;
  jmethodID listInit_ = nullptr;
  jmethodID listAdd_ = nullptr;
  bool ready_ = false;
};

} // namespace

static jobjectArray toJavaStrings(JNIEnv *env, const std::vector<std::string_view> &strings) {
  jclass stringClass = env->FindClass("java/lang/String");
  jobjectArray array = env->NewObjectArray(static_cast<jsize>(strings.size()), stringClass, nullptr);
  for (size_t i = 0; i < strings.size(); i++) {
    jstring value = javaString(env, strings[i]);
    env->SetObjectArrayElement(array, static_cast<jsize>(i), value);
    env->DeleteLocalRef(value);
  }
  env->DeleteLocalRef(stringClass);
  return array;
}

// A host exception must not leak into later JNI calls; recognition is dropped for that call.
static bool clearHostException(JNIEnv *env) {
  if (!env->ExceptionCheck())
    return false;
  env->ExceptionDescribe();
  env->ExceptionClear();
  return true;
}

// Host matchers for the core recognizer: one JNI round trip per kind per parse, into TextLinkMatching.
// Capturing env is safe because the core invokes these synchronously, inside this native call.
static Markdown::TextLinkMatchers makeTextLinkMatchers(JNIEnv *env, jobject textConfig, jobject codeConfig) {
  Markdown::TextLinkMatchers matchers;
  if (!textConfig && !codeConfig)
    return matchers;
  jclass matchingClass = env->FindClass("com/swmansion/enriched/markdown/parser/TextLinkMatching");
  if (!matchingClass) {
    clearHostException(env);
    return matchers;
  }
  const char *configSig = "com/swmansion/enriched/markdown/utils/common/LinkRegexConfig";

  if (textConfig) {
    jmethodID method = env->GetStaticMethodID(matchingClass, "matchText",
                                              ("([Ljava/lang/String;L" + std::string(configSig) + ";)[I").c_str());
    if (!method) {
      clearHostException(env);
      return matchers;
    }
    matchers.text = [env, matchingClass, method, textConfig](const std::vector<std::string_view> &runs) {
      std::vector<std::vector<Markdown::TextRange>> all(runs.size());
      jobjectArray javaRuns = toJavaStrings(env, runs);
      jintArray triples = (jintArray)env->CallStaticObjectMethod(matchingClass, method, javaRuns, textConfig);
      env->DeleteLocalRef(javaRuns);
      if (clearHostException(env))
        return all;
      if (triples) {
        jsize count = env->GetArrayLength(triples);
        jint *data = env->GetIntArrayElements(triples, nullptr);
        for (jsize i = 0; i + 2 < count; i += 3) {
          size_t run = static_cast<size_t>(data[i]);
          if (run < all.size())
            all[run].push_back({static_cast<size_t>(data[i + 1]), static_cast<size_t>(data[i + 2])});
        }
        env->ReleaseIntArrayElements(triples, data, JNI_ABORT);
        env->DeleteLocalRef(triples);
      }
      return all;
    };
  }

  if (codeConfig) {
    jmethodID method = env->GetStaticMethodID(matchingClass, "matchWholeCode",
                                              ("([Ljava/lang/String;L" + std::string(configSig) + ";)[Z").c_str());
    if (!method) {
      clearHostException(env);
      return matchers;
    }
    matchers.inlineCode = [env, matchingClass, method, codeConfig](const std::vector<std::string_view> &spans) {
      std::vector<uint8_t> matched(spans.size(), 0);
      jobjectArray javaSpans = toJavaStrings(env, spans);
      jbooleanArray flags = (jbooleanArray)env->CallStaticObjectMethod(matchingClass, method, javaSpans, codeConfig);
      env->DeleteLocalRef(javaSpans);
      if (clearHostException(env))
        return matched;
      if (flags) {
        jsize count = env->GetArrayLength(flags);
        jboolean *data = env->GetBooleanArrayElements(flags, nullptr);
        for (jsize i = 0; i < count && static_cast<size_t>(i) < matched.size(); i++)
          matched[i] = data[i] == JNI_TRUE ? 1 : 0;
        env->ReleaseBooleanArrayElements(flags, data, JNI_ABORT);
        env->DeleteLocalRef(flags);
      }
      return matched;
    };
  }
  return matchers;
}

// The Kotlin Md4cFlags data class as the core's flags; defaults for null.
static Md4cFlags md4cFlagsFromJava(JNIEnv *env, jobject flags) {
  Md4cFlags md4cFlags;
  if (flags) {
    jclass flagsClass = env->GetObjectClass(flags);
    if (flagsClass) {
      jfieldID underlineField = env->GetFieldID(flagsClass, "underline", "Z");
      if (underlineField) {
        md4cFlags.underline = env->GetBooleanField(flags, underlineField) == JNI_TRUE;
      }
      jfieldID latexMathField = env->GetFieldID(flagsClass, "latexMath", "Z");
      if (latexMathField) {
        md4cFlags.latexMath = env->GetBooleanField(flags, latexMathField) == JNI_TRUE;
      }
      jfieldID superscriptField = env->GetFieldID(flagsClass, "superscript", "Z");
      if (superscriptField) {
        md4cFlags.superscript = env->GetBooleanField(flags, superscriptField) == JNI_TRUE;
      }
      jfieldID subscriptField = env->GetFieldID(flagsClass, "subscript", "Z");
      if (subscriptField) {
        md4cFlags.subscript = env->GetBooleanField(flags, subscriptField) == JNI_TRUE;
      }
      jfieldID strikethroughField = env->GetFieldID(flagsClass, "strikethrough", "Z");
      if (strikethroughField) {
        md4cFlags.strikethrough = env->GetBooleanField(flags, strikethroughField) == JNI_TRUE;
      }
      jfieldID highlightField = env->GetFieldID(flagsClass, "highlight", "Z");
      if (highlightField) {
        md4cFlags.highlight = env->GetBooleanField(flags, highlightField) == JNI_TRUE;
      }
      jfieldID permissiveAutolinksField = env->GetFieldID(flagsClass, "permissiveAutolinks", "Z");
      if (permissiveAutolinksField) {
        md4cFlags.permissiveAutolinks = env->GetBooleanField(flags, permissiveAutolinksField) == JNI_TRUE;
      }
      jfieldID hardSoftBreaksField = env->GetFieldID(flagsClass, "hardSoftBreaks", "Z");
      if (hardSoftBreaksField) {
        md4cFlags.hardSoftBreaks = env->GetBooleanField(flags, hardSoftBreaksField) == JNI_TRUE;
      }
      jfieldID preserveBlankLinesField = env->GetFieldID(flagsClass, "preserveBlankLines", "Z");
      if (preserveBlankLinesField) {
        md4cFlags.preserveBlankLines = env->GetBooleanField(flags, preserveBlankLinesField) == JNI_TRUE;
      }
      jfieldID admonitionsField = env->GetFieldID(flagsClass, "admonitions", "Z");
      if (admonitionsField) {
        md4cFlags.admonitions = env->GetBooleanField(flags, admonitionsField) == JNI_TRUE;
      }
      env->DeleteLocalRef(flagsClass);
    }
  }
  return md4cFlags;
}

// The core's streaming effects (StreamingEffects.hpp) and pacer (StreamingPacer.hpp), one per view; Kotlin holds
// the pointer.
namespace {
Markdown::EffectColor effectColor(jint argb) {
  auto channel = [&](int shift) { return static_cast<float>((static_cast<uint32_t>(argb) >> shift) & 0xFF) / 255.0f; };
  return {channel(16), channel(8), channel(0), channel(24)};
}

jint argbOf(const Markdown::EffectColor &color) {
  auto channel = [](float value, int shift) {
    return static_cast<uint32_t>(std::clamp(value, 0.0f, 1.0f) * 255.0f + 0.5f) << shift;
  };
  return static_cast<jint>(channel(color.a, 24) | channel(color.r, 16) | channel(color.g, 8) | channel(color.b, 0));
}

Markdown::StreamingEffects *effectsOf(jlong handle) {
  return reinterpret_cast<Markdown::StreamingEffects *>(handle);
}

Markdown::StreamingPacer *pacerOf(jlong handle) {
  return reinterpret_cast<Markdown::StreamingPacer *>(handle);
}
} // namespace

extern "C" {

JNIEXPORT jobject JNICALL Java_com_swmansion_enriched_markdown_parser_Parser_nativeParseMarkdown(
    JNIEnv *env, jobject /* this */, jstring markdown, jobject flags, jboolean isGFM, jobject textLinkRegex,
    jobject inlineCodeLinkRegex, jobjectArray activeBlockSlotIds, jboolean annotateImages) {
  if (!markdown) {
    LOGE("Markdown string is null");
    return nullptr;
  }

  try {
    Md4cFlags md4cFlags = md4cFlagsFromJava(env, flags);
    auto document = DocumentStore::shared().parse(utf8String(env, markdown), md4cFlags, isGFM == JNI_TRUE);
    if (!document->ast) {
      return nullptr;
    }

    // Slots and image overrides are GFM features (the CommonMark host lays nothing
    // out for them). The ids come from the shared document's collector, the one
    // the JS side read, and are added while converting; the tree stays as parsed.
    std::unordered_set<std::string> ids;
    bool withImageIds = isGFM == JNI_TRUE && annotateImages == JNI_TRUE;
    if (isGFM == JNI_TRUE && activeBlockSlotIds) {
      jsize count = env->GetArrayLength(activeBlockSlotIds);
      for (jsize i = 0; i < count; i++) {
        jstring id = (jstring)env->GetObjectArrayElement(activeBlockSlotIds, i);
        if (!id)
          continue;
        ids.insert(utf8String(env, id));
        env->DeleteLocalRef(id);
      }
    }
    TextLinkReplacements links;
    if (textLinkRegex || inlineCodeLinkRegex) {
      links = recognizeTextLinks(*document->ast, makeTextLinkMatchers(env, textLinkRegex, inlineCodeLinkRegex));
    }
    AstOverlay overlay(*document, std::move(ids), withImageIds, std::move(links));

    jobject javaNode = JavaNodeFactory(env).create(*document->ast, overlay);
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

// The core's streaming session (StreamingSession.hpp), shared with iOS and the
// JS block collector. Returns a StreamingFilterResult, or null if that class
// cannot be constructed (the caller then renders the markdown as it is).
JNIEXPORT jobject JNICALL
Java_com_swmansion_enriched_markdown_utils_common_StreamingMarkdownFilter_nativeRenderableMarkdownForStreaming(
    JNIEnv *env, jclass /* clazz */, jstring markdown, jobject flags, jboolean hideTables, jboolean hideCodeBlocks,
    jboolean hideMedia) {
  if (!markdown) {
    return nullptr;
  }
  Markdown::StreamingOptions options;
  options.blocks.tableMode =
      hideTables == JNI_TRUE ? Markdown::StreamingBlockMode::Hidden : Markdown::StreamingBlockMode::Progressive;
  options.blocks.codeBlockMode =
      hideCodeBlocks == JNI_TRUE ? Markdown::StreamingBlockMode::Hidden : Markdown::StreamingBlockMode::Progressive;
  options.blocks.mediaMode =
      hideMedia == JNI_TRUE ? Markdown::StreamingBlockMode::Hidden : Markdown::StreamingBlockMode::Progressive;
  options.flags = md4cFlagsFromJava(env, flags);
  // Through the shared store: the tick's collect, measurement and render prepare once.
  Markdown::StreamingSnapshot result = DocumentStore::shared().snapshot(utf8String(env, markdown), options);

  // consumer-rules.pro keeps the class; a failed lookup leaves a pending
  // exception that would throw in Kotlin instead of returning null.
  jclass resultClass = env->FindClass("com/swmansion/enriched/markdown/utils/common/StreamingFilterResult");
  if (!resultClass) {
    env->ExceptionClear();
    return nullptr;
  }
  jmethodID constructor = env->GetMethodID(resultClass, "<init>", "(Ljava/lang/String;Z)V");
  if (!constructor) {
    env->ExceptionClear();
    env->DeleteLocalRef(resultClass);
    return nullptr;
  }
  jstring filtered = javaString(env, result.markdown);
  jobject object =
      env->NewObject(resultClass, constructor, filtered, result.endsInsideOpenCodeFence ? JNI_TRUE : JNI_FALSE);
  env->DeleteLocalRef(filtered);
  env->DeleteLocalRef(resultClass);
  return object;
}

// Called by MeasurementStore's walk while the GFM shadow node measures; see
// BlockSlotMeasureSession. Outside a measurement there is no session and no slot.
JNIEXPORT jfloat JNICALL Java_com_swmansion_enriched_markdown_MeasurementStore_nativeMeasureBlockSlot(
    JNIEnv *env, jclass /* clazz */, jstring slotId, jfloat x, jfloat y, jfloat width) {
  auto *session = facebook::react::BlockSlotMeasureSession::current();
  if (!session || !slotId) {
    return 0;
  }
  return session->measure(utf8String(env, slotId), x, y, width);
}

JNIEXPORT void JNICALL Java_com_swmansion_enriched_markdown_MeasurementStore_nativeDiscardBlockSlotFrames(
    JNIEnv * /* env */, jclass /* clazz */) {
  if (auto *session = facebook::react::BlockSlotMeasureSession::current()) {
    session->discard();
  }
}

JNIEXPORT jstring JNICALL Java_com_swmansion_enriched_markdown_utils_common_CodeBlockNode_nativeDisplayLanguageName(
    JNIEnv *env, jobject /* this */, jstring language) {
  if (!language) {
    return nullptr;
  }
  const char *languageStr = env->GetStringUTFChars(language, nullptr);
  if (!languageStr) {
    return nullptr;
  }
  std::string display = displayNameForLanguage(languageStr);
  env->ReleaseStringUTFChars(language, languageStr);
  return env->NewStringUTF(display.c_str());
}

JNIEXPORT jstring JNICALL Java_com_swmansion_enriched_markdown_math_LatexSpeech_nativeSpokenForm(JNIEnv *env,
                                                                                                 jobject /* this */,
                                                                                                 jstring latex) {
  return javaString(env, spokenLatex(utf8String(env, latex)));
}

// Returns highlight tokens as (start, end, type) int triplets with UTF-16
// offsets, or null when highlighting is unavailable. See
// cpp/highlight/CodeBlockHighlighter.hpp for the seam contract.
JNIEXPORT jintArray JNICALL Java_com_swmansion_enriched_markdown_utils_common_CodeBlockHighlighter_nativeHighlightCode(
    JNIEnv *env, jobject /* this */, jstring code, jstring language) {
  if (!code) {
    return nullptr;
  }

  const char *codeStr = env->GetStringUTFChars(code, nullptr);
  if (!codeStr) {
    return nullptr;
  }
  const char *languageStr = language ? env->GetStringUTFChars(language, nullptr) : nullptr;

  std::vector<HighlightToken> tokens;
  try {
    tokens = highlightCode(codeStr, languageStr ? languageStr : "");
  } catch (const std::exception &e) {
    LOGE("Exception during highlighting: %s", e.what());
    tokens.clear();
  } catch (...) {
    LOGE("Unknown exception during highlighting");
    tokens.clear();
  }

  env->ReleaseStringUTFChars(code, codeStr);
  if (languageStr) {
    env->ReleaseStringUTFChars(language, languageStr);
  }

  if (tokens.empty()) {
    return nullptr;
  }

  std::vector<jint> flat;
  flat.reserve(tokens.size() * 3);
  for (const auto &token : tokens) {
    flat.push_back(static_cast<jint>(token.start));
    flat.push_back(static_cast<jint>(token.end));
    flat.push_back(static_cast<jint>(token.type));
  }

  jintArray result = env->NewIntArray(static_cast<jsize>(flat.size()));
  if (!result) {
    return nullptr;
  }
  env->SetIntArrayRegion(result, 0, static_cast<jsize>(flat.size()), flat.data());
  return result;
}

JNIEXPORT jlong JNICALL Java_com_swmansion_enriched_markdown_utils_text_StreamingEffects_nativeCreate(JNIEnv *,
                                                                                                      jclass) {
  return reinterpret_cast<jlong>(new Markdown::StreamingEffects());
}

JNIEXPORT void JNICALL Java_com_swmansion_enriched_markdown_utils_text_StreamingEffects_nativeDestroy(JNIEnv *, jclass,
                                                                                                      jlong handle) {
  delete effectsOf(handle);
}

JNIEXPORT void JNICALL Java_com_swmansion_enriched_markdown_utils_text_StreamingEffects_nativeConfigure(
    JNIEnv *, jclass, jlong handle, jint type, jdouble duration, jint length, jboolean hasStartColor, jint startColor,
    jboolean hasEndColor, jint endColor) {
  Markdown::StreamingEffectConfig config;
  config.type = type == 2   ? Markdown::StreamingEffectType::Gradient
                : type == 1 ? Markdown::StreamingEffectType::Fade
                            : Markdown::StreamingEffectType::None;
  config.duration = duration;
  config.length = static_cast<size_t>(std::max(length, 1));
  if (hasStartColor == JNI_TRUE) {
    config.startColor = effectColor(startColor);
  }
  if (hasEndColor == JNI_TRUE) {
    config.endColor = effectColor(endColor);
  }
  effectsOf(handle)->configure(config);
}

JNIEXPORT void JNICALL Java_com_swmansion_enriched_markdown_utils_text_StreamingEffects_nativeNoteArrival(
    JNIEnv *env, jclass, jlong handle, jint start, jint end, jdouble time, jstring text, jchar previous) {
  const jchar *chars = env->GetStringChars(text, nullptr);
  std::u16string_view added(reinterpret_cast<const char16_t *>(chars), static_cast<size_t>(env->GetStringLength(text)));
  effectsOf(handle)->noteArrival(static_cast<size_t>(std::max(start, 0)), static_cast<size_t>(std::max(end, 0)), time,
                                 added, static_cast<char16_t>(previous));
  env->ReleaseStringChars(text, chars);
}

JNIEXPORT void JNICALL Java_com_swmansion_enriched_markdown_utils_text_StreamingEffects_nativeFinish(JNIEnv *, jclass,
                                                                                                     jlong handle,
                                                                                                     jdouble time) {
  effectsOf(handle)->finish(time);
}

JNIEXPORT void JNICALL Java_com_swmansion_enriched_markdown_utils_text_StreamingEffects_nativeReset(JNIEnv *, jclass,
                                                                                                    jlong handle) {
  effectsOf(handle)->reset();
}

JNIEXPORT jboolean JNICALL Java_com_swmansion_enriched_markdown_utils_text_StreamingEffects_nativeChangesOverTime(
    JNIEnv *, jclass, jlong handle, jdouble time) {
  return effectsOf(handle)->changesOverTime(time) ? JNI_TRUE : JNI_FALSE;
}

// The animated range as (start << 32 | length), or -1 for none.
JNIEXPORT jlong JNICALL Java_com_swmansion_enriched_markdown_utils_text_StreamingEffects_nativeAnimatedRange(
    JNIEnv *, jclass, jlong handle, jdouble time) {
  auto range = effectsOf(handle)->animatedRange(time);
  if (!range) {
    return -1;
  }
  return (static_cast<jlong>(range->start) << 32) | static_cast<jlong>(range->length & 0xFFFFFFFF);
}

// The looks of `count` characters from `start`, in one call per frame.
JNIEXPORT void JNICALL Java_com_swmansion_enriched_markdown_utils_text_StreamingEffects_nativeLooks(
    JNIEnv *env, jclass, jlong handle, jint start, jint count, jdouble time, jintArray tints, jfloatArray tintAmounts,
    jfloatArray opacities) {
  if (count <= 0) {
    return;
  }
  std::vector<jint> tintValues(count);
  std::vector<jfloat> amountValues(count);
  std::vector<jfloat> opacityValues(count);
  auto *effects = effectsOf(handle);
  for (jint i = 0; i < count; i++) {
    Markdown::CharacterLook look = effects->lookAt(static_cast<size_t>(start + i), time);
    tintValues[i] = argbOf(look.tint);
    amountValues[i] = look.tintAmount;
    opacityValues[i] = look.opacity;
  }
  env->SetIntArrayRegion(tints, 0, count, tintValues.data());
  env->SetFloatArrayRegion(tintAmounts, 0, count, amountValues.data());
  env->SetFloatArrayRegion(opacities, 0, count, opacityValues.data());
}

JNIEXPORT jlong JNICALL Java_com_swmansion_enriched_markdown_utils_text_StreamingPacer_nativeCreate(JNIEnv *, jclass) {
  return reinterpret_cast<jlong>(new Markdown::StreamingPacer());
}

JNIEXPORT void JNICALL Java_com_swmansion_enriched_markdown_utils_text_StreamingPacer_nativeDestroy(JNIEnv *, jclass,
                                                                                                    jlong handle) {
  delete pacerOf(handle);
}

JNIEXPORT void JNICALL Java_com_swmansion_enriched_markdown_utils_text_StreamingPacer_nativeAppend(
    JNIEnv *env, jclass, jlong handle, jint start, jstring added, jdouble time) {
  const jchar *chars = env->GetStringChars(added, nullptr);
  std::u16string_view text(reinterpret_cast<const char16_t *>(chars), static_cast<size_t>(env->GetStringLength(added)));
  pacerOf(handle)->append(static_cast<size_t>(std::max(start, 0)), text, time);
  env->ReleaseStringChars(added, chars);
}

JNIEXPORT void JNICALL Java_com_swmansion_enriched_markdown_utils_text_StreamingPacer_nativeReset(JNIEnv *, jclass,
                                                                                                  jlong handle,
                                                                                                  jint length) {
  pacerOf(handle)->reset(static_cast<size_t>(std::max(length, 0)));
}

JNIEXPORT void JNICALL Java_com_swmansion_enriched_markdown_utils_text_StreamingPacer_nativeFinish(JNIEnv *, jclass,
                                                                                                   jlong handle,
                                                                                                   jdouble time) {
  pacerOf(handle)->finish(time);
}

JNIEXPORT jint JNICALL Java_com_swmansion_enriched_markdown_utils_text_StreamingPacer_nativeRevealed(JNIEnv *, jclass,
                                                                                                     jlong handle,
                                                                                                     jdouble time) {
  return static_cast<jint>(pacerOf(handle)->revealed(time));
}

JNIEXPORT jboolean JNICALL Java_com_swmansion_enriched_markdown_utils_text_StreamingPacer_nativeWaiting(JNIEnv *,
                                                                                                        jclass,
                                                                                                        jlong handle,
                                                                                                        jdouble time) {
  return pacerOf(handle)->waiting(time) ? JNI_TRUE : JNI_FALSE;
}

} // extern "C"
