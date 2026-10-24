#pragma once

#ifdef __cplusplus
extern "C" {
#endif

// Caller releases with em_repair_release.
char *em_repair_inline_markdown(const char *markdown, int highlight);
void em_repair_release(char *string);

#ifdef __cplusplus
}
#endif
