#include "SwiftHighlightCAPI.h"

#include "CodeBlockHighlighter.hpp"

#include <cstdlib>
#include <string>
#include <vector>

static_assert(static_cast<int>(Markdown::HighlightTokenType::Keyword) == 0,
              "HighlightTokenType enum must stay in sync with Swift SyntaxTokenType");
static_assert(static_cast<int>(Markdown::HighlightTokenType::Embedded) == 13,
              "HighlightTokenType enum must stay in sync with Swift SyntaxTokenType");

extern "C" {

EMHighlightToken *em_highlight_code(const char *code, size_t codeLength, const char *language, size_t *tokenCount) {
  if (tokenCount) {
    *tokenCount = 0;
  }
  if (!code || codeLength == 0 || !language || !tokenCount) {
    return nullptr;
  }

  try {
    std::vector<Markdown::HighlightToken> tokens =
        Markdown::highlightCode(std::string(code, codeLength), std::string(language));
    if (tokens.empty()) {
      return nullptr;
    }

    auto *result = static_cast<EMHighlightToken *>(std::malloc(tokens.size() * sizeof(EMHighlightToken)));
    if (!result) {
      return nullptr;
    }
    for (size_t i = 0; i < tokens.size(); ++i) {
      result[i] = {tokens[i].start, tokens[i].end, static_cast<uint8_t>(tokens[i].type)};
    }
    *tokenCount = tokens.size();
    return result;
  } catch (...) {
    return nullptr;
  }
}

void em_highlight_tokens_release(EMHighlightToken *tokens) {
  std::free(tokens);
}

} // extern "C"
