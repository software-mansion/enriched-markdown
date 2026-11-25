// JNI entry points of the editable input's markdown import and export. Kept apart
// from jni-adapter.cpp because they need nothing but jni.h and the input core,
// which lets the unit tests build them as a host library (see build.gradle).
#include "MarkdownInput.hpp"
#include <algorithm>
#include <jni.h>
#include <string>
#include <vector>

#ifdef __ANDROID__
#include <android/log.h>
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, "EnrichedMarkdownJNI", __VA_ARGS__)
#else
#include <cstdio>
#define LOGE(...) (std::fprintf(stderr, __VA_ARGS__), std::fputc('\n', stderr))
#endif

namespace {

// The input core (cpp/input) works on UTF-16 like Java strings, so text crosses as
// is. Ranges are packed as ints: (type, start, end) for formatting and
// (type, start, end, level, ordinal) for blocks, with link URLs in an array that
// runs parallel to the formatting ranges (null where a range has none).
constexpr jsize kFormattingStride = 3;
constexpr jsize kBlockStride = 5;

std::u16string utf16String(JNIEnv *env, jstring string) {
  if (!string)
    return {};
  std::u16string utf16(static_cast<size_t>(env->GetStringLength(string)), u'\0');
  env->GetStringRegion(string, 0, static_cast<jsize>(utf16.size()), reinterpret_cast<jchar *>(utf16.data()));
  return utf16;
}

jstring javaUtf16String(JNIEnv *env, const std::u16string &utf16) {
  return env->NewString(reinterpret_cast<const jchar *>(utf16.data()), static_cast<jsize>(utf16.size()));
}

jintArray javaInts(JNIEnv *env, const std::vector<jint> &values) {
  jintArray array = env->NewIntArray(static_cast<jsize>(values.size()));
  if (array && !values.empty())
    env->SetIntArrayRegion(array, 0, static_cast<jsize>(values.size()), values.data());
  return array;
}

jint nonNegative(jint value) {
  return value < 0 ? 0 : value;
}

} // namespace

extern "C" {

// Markdown to plain text and ranges through the shared input core. Returns
// Object[] { String text, int[] formatting, int[] blocks, String[] urls }, or null
// when anything fails (the caller then keeps the markdown as plain text).
JNIEXPORT jobjectArray JNICALL Java_com_swmansion_enriched_markdown_input_formatting_InputParser_nativeParse(
    JNIEnv *env, jclass /* clazz */, jstring markdown) {
  if (!markdown)
    return nullptr;
  try {
    Markdown::Input::ParseResult parsed = Markdown::Input::parse(utf16String(env, markdown));

    std::vector<jint> formatting;
    formatting.reserve(parsed.formattingRanges.size() * kFormattingStride);
    for (const auto &range : parsed.formattingRanges) {
      formatting.push_back(static_cast<jint>(range.type));
      formatting.push_back(static_cast<jint>(range.start));
      formatting.push_back(static_cast<jint>(range.end));
    }
    std::vector<jint> blocks;
    blocks.reserve(parsed.blockRanges.size() * kBlockStride);
    for (const auto &block : parsed.blockRanges) {
      blocks.push_back(static_cast<jint>(block.type));
      blocks.push_back(static_cast<jint>(block.start));
      blocks.push_back(static_cast<jint>(block.end));
      blocks.push_back(static_cast<jint>(block.level));
      blocks.push_back(static_cast<jint>(block.ordinal));
    }

    jclass objectClass = env->FindClass("java/lang/Object");
    jclass stringClass = env->FindClass("java/lang/String");
    if (!objectClass || !stringClass) {
      env->ExceptionClear();
      return nullptr;
    }
    jobjectArray result = env->NewObjectArray(4, objectClass, nullptr);
    jobjectArray urls = env->NewObjectArray(static_cast<jsize>(parsed.formattingRanges.size()), stringClass, nullptr);
    jstring text = javaUtf16String(env, parsed.plainText);
    jintArray formattingArray = javaInts(env, formatting);
    jintArray blockArray = javaInts(env, blocks);
    if (!result || !urls || !text || !formattingArray || !blockArray || env->ExceptionCheck()) {
      env->ExceptionClear();
      return nullptr;
    }
    for (size_t i = 0; i < parsed.formattingRanges.size(); i++) {
      if (parsed.formattingRanges[i].type != Markdown::Input::StyleType::Link)
        continue;
      jstring url = javaUtf16String(env, parsed.formattingRanges[i].url);
      if (!url) {
        env->ExceptionClear();
        return nullptr;
      }
      env->SetObjectArrayElement(urls, static_cast<jsize>(i), url);
      env->DeleteLocalRef(url);
    }
    env->SetObjectArrayElement(result, 0, text);
    env->SetObjectArrayElement(result, 1, formattingArray);
    env->SetObjectArrayElement(result, 2, blockArray);
    env->SetObjectArrayElement(result, 3, urls);
    return result;
  } catch (...) {
    LOGE("Exception during input parsing");
    env->ExceptionClear();
    return nullptr;
  }
}

// The reverse, through the same core. `formatting` and `blocks` are packed as
// above, `urls` runs parallel to `formatting`. Returns null on any failure (the
// caller then keeps the plain text).
JNIEXPORT jstring JNICALL Java_com_swmansion_enriched_markdown_input_formatting_MarkdownSerializer_nativeSerialize(
    JNIEnv *env, jclass /* clazz */, jstring text, jintArray formatting, jobjectArray urls, jintArray blocks) {
  if (!text)
    return nullptr;
  try {
    std::vector<Markdown::Input::FormattingRange> formattingRanges;
    if (formatting) {
      jsize count = env->GetArrayLength(formatting) / kFormattingStride;
      std::vector<jint> data(static_cast<size_t>(count) * kFormattingStride);
      if (count > 0)
        env->GetIntArrayRegion(formatting, 0, count * kFormattingStride, data.data());
      jsize urlCount = urls ? env->GetArrayLength(urls) : 0;
      formattingRanges.reserve(static_cast<size_t>(count));
      for (jsize i = 0; i < count; i++) {
        jint type = data[i * kFormattingStride];
        if (type < static_cast<jint>(Markdown::Input::StyleType::Strong) ||
            type > static_cast<jint>(Markdown::Input::StyleType::Spoiler))
          continue;
        Markdown::Input::FormattingRange range;
        range.type = static_cast<Markdown::Input::StyleType>(type);
        range.start = static_cast<uint32_t>(nonNegative(data[i * kFormattingStride + 1]));
        range.end = static_cast<uint32_t>(nonNegative(data[i * kFormattingStride + 2]));
        if (i < urlCount) {
          jstring url = static_cast<jstring>(env->GetObjectArrayElement(urls, i));
          if (url) {
            range.url = utf16String(env, url);
            env->DeleteLocalRef(url);
          }
        }
        formattingRanges.push_back(std::move(range));
      }
    }

    std::vector<Markdown::Input::BlockRange> blockRanges;
    if (blocks) {
      jsize count = env->GetArrayLength(blocks) / kBlockStride;
      std::vector<jint> data(static_cast<size_t>(count) * kBlockStride);
      if (count > 0)
        env->GetIntArrayRegion(blocks, 0, count * kBlockStride, data.data());
      blockRanges.reserve(static_cast<size_t>(count));
      for (jsize i = 0; i < count; i++) {
        jint type = data[i * kBlockStride];
        if (type < static_cast<jint>(Markdown::Input::BlockType::Paragraph) ||
            type > static_cast<jint>(Markdown::Input::BlockType::OrderedListItem))
          continue;
        Markdown::Input::BlockRange block;
        block.type = static_cast<Markdown::Input::BlockType>(type);
        block.start = static_cast<uint32_t>(nonNegative(data[i * kBlockStride + 1]));
        block.end = static_cast<uint32_t>(nonNegative(data[i * kBlockStride + 2]));
        block.level = static_cast<uint8_t>(std::min<jint>(nonNegative(data[i * kBlockStride + 3]), 255));
        block.ordinal = static_cast<uint32_t>(nonNegative(data[i * kBlockStride + 4]));
        blockRanges.push_back(block);
      }
    }
    if (env->ExceptionCheck()) {
      env->ExceptionClear();
      return nullptr;
    }

    std::u16string markdown = Markdown::Input::serialize(utf16String(env, text), formattingRanges, blockRanges);
    return javaUtf16String(env, markdown);
  } catch (...) {
    LOGE("Exception during input serialization");
    env->ExceptionClear();
    return nullptr;
  }
}

} // extern "C"
