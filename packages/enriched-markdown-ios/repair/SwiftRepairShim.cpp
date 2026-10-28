#include "SwiftRepairCAPI.h"

#include "MarkdownRepair.hpp"

#include <cstdlib>
#include <cstring>

extern "C" {

char *em_repair_inline_markdown(const char *markdown, int highlight, int latexMath) {
  if (!markdown) {
    return nullptr;
  }

  Markdown::RepairOptions options;
  options.linkMode = Markdown::LinkMode::TextOnly;
  options.inlineMath = latexMath != 0;
  options.displayMath = latexMath != 0;
  options.highlight = highlight != 0;
  options.withholdIncomplete = true;
  options.withholdMath = true;

  try {
    return strdup(Markdown::repairInlineMarkdown(markdown, options).c_str());
  } catch (...) {
    return nullptr;
  }
}

void em_repair_release(char *string) {
  std::free(string);
}

} // extern "C"
