#include "CodeBlockHighlighter.hpp"

#include <jni.h>

#include <cstddef>
#include <string>
#include <vector>

using namespace Markdown;

namespace {

// Token types cross JNI as their integer value, and the Kotlin side indexes by it. Pin the order
// and count here so a change to the seam's enum fails the build instead of recoloring tokens.
constexpr HighlightTokenType kTokenTypeOrder[] = {
    HighlightTokenType::Keyword,   HighlightTokenType::Operator, HighlightTokenType::Punctuation,
    HighlightTokenType::String,    HighlightTokenType::Number,   HighlightTokenType::Constant,
    HighlightTokenType::Comment,   HighlightTokenType::Function, HighlightTokenType::Type,
    HighlightTokenType::Variable,  HighlightTokenType::Property, HighlightTokenType::Tag,
    HighlightTokenType::Attribute, HighlightTokenType::Embedded,
};

constexpr bool tokenTypeOrderMatches() {
  for (std::size_t i = 0; i < sizeof(kTokenTypeOrder) / sizeof(kTokenTypeOrder[0]); ++i) {
    if (static_cast<std::size_t>(kTokenTypeOrder[i]) != i) {
      return false;
    }
  }
  return true;
}

static_assert(sizeof(kTokenTypeOrder) / sizeof(kTokenTypeOrder[0]) == 14,
              "HighlightTokenType count changed; Kotlin indexes token types by value");
static_assert(tokenTypeOrderMatches(), "HighlightTokenType order changed; Kotlin indexes token types by value");

jintArray emptyArray(JNIEnv *env) {
  return env->NewIntArray(0);
}

} // namespace

extern "C" {

// Returns flat (start, end, tokenType) triplets with UTF-16 offsets into the code, or an empty
// array whenever highlighting is unavailable (unknown language, input past the seam's size cap,
// parse failure). The code arrives as standard UTF-8 bytes rather than a jstring, because
// GetStringUTFChars yields modified UTF-8, which encodes astral code points as two 3-byte
// surrogates and would skew every offset after an emoji.
JNIEXPORT jintArray JNICALL Java_com_swmansion_enriched_markdown_syntaxhighlighting_SyntaxHighlighterNative_highlight(
    JNIEnv *env, jobject /* this */, jbyteArray code, jstring language) {
  if (code == nullptr || language == nullptr) {
    return emptyArray(env);
  }

  const jsize codeLength = env->GetArrayLength(code);
  std::string codeStr(static_cast<std::size_t>(codeLength), '\0');
  if (codeLength > 0) {
    env->GetByteArrayRegion(code, 0, codeLength, reinterpret_cast<jbyte *>(&codeStr[0]));
  }

  // Fence languages are ASCII, so modified UTF-8 is harmless here.
  const char *languageChars = env->GetStringUTFChars(language, nullptr);
  if (languageChars == nullptr) {
    return nullptr; // OutOfMemoryError pending.
  }
  std::string languageStr(languageChars);
  env->ReleaseStringUTFChars(language, languageChars);

  std::vector<jint> flat;
  try {
    std::vector<HighlightToken> tokens = highlightCode(codeStr, languageStr);
    flat.reserve(tokens.size() * 3);
    for (const HighlightToken &token : tokens) {
      flat.push_back(static_cast<jint>(token.start));
      flat.push_back(static_cast<jint>(token.end));
      flat.push_back(static_cast<jint>(token.type));
    }
  } catch (...) {
    flat.clear();
  }

  jintArray result = env->NewIntArray(static_cast<jsize>(flat.size()));
  if (result != nullptr && !flat.empty()) {
    env->SetIntArrayRegion(result, 0, static_cast<jsize>(flat.size()), flat.data());
  }
  return result;
}

} // extern "C"
