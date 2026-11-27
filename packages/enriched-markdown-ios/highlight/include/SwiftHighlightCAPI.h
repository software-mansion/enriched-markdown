#pragma once

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct EMHighlightToken {
  uint32_t start;
  uint32_t end;
  uint8_t type;
} EMHighlightToken;

EMHighlightToken *em_highlight_code(const char *code, size_t codeLength, const char *language, size_t *tokenCount);

void em_highlight_tokens_release(EMHighlightToken *tokens);

#ifdef __cplusplus
}
#endif
