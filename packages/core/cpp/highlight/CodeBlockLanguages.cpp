#include "CodeBlockLanguages.hpp"

#include <algorithm>
#include <array>
#include <cctype>
#include <cstring>

namespace Markdown {

namespace {

struct LanguageName {
  const char *key;
  const char *name;
  // Canonical tree-sitter grammar id (vendored directory name), or "" when no
  // grammar covers this fence language.
  const char *grammar;
};

// Sorted by key; both lookups below binary-search this table.
constexpr std::array<LanguageName, 44> kLanguageNames{{
    {"bash", "Bash", "bash"},
    {"c", "C", "c"},
    {"cc", "C++", "cpp"},
    {"cpp", "C++", "cpp"},
    {"cs", "C#", "c-sharp"},
    {"csharp", "C#", "c-sharp"},
    {"css", "CSS", "css"},
    {"cxx", "C++", "cpp"},
    {"dockerfile", "Dockerfile", ""},
    {"go", "Go", "go"},
    {"golang", "Go", "go"},
    {"graphql", "GraphQL", ""},
    {"html", "HTML", "html"},
    {"java", "Java", "java"},
    {"javascript", "JavaScript", "javascript"},
    {"js", "JavaScript", "javascript"},
    {"json", "JSON", "json"},
    {"jsx", "JSX", "javascript"},
    {"kotlin", "Kotlin", "kotlin"},
    {"kt", "Kotlin", "kotlin"},
    {"markdown", "Markdown", "markdown"},
    {"md", "Markdown", "markdown"},
    {"objc", "Objective-C", ""},
    {"objectivec", "Objective-C", ""},
    {"php", "PHP", "php"},
    {"py", "Python", "python"},
    {"python", "Python", "python"},
    {"rb", "Ruby", "ruby"},
    {"ruby", "Ruby", "ruby"},
    {"rs", "Rust", "rust"},
    {"rust", "Rust", "rust"},
    {"scss", "SCSS", ""},
    {"sh", "Shell", "bash"},
    {"shell", "Shell", "bash"},
    {"sql", "SQL", ""},
    {"swift", "Swift", "swift"},
    {"toml", "TOML", ""},
    {"ts", "TypeScript", "typescript"},
    {"tsx", "TSX", "tsx"},
    {"typescript", "TypeScript", "typescript"},
    {"xml", "XML", ""},
    {"yaml", "YAML", "yaml"},
    {"yml", "YAML", "yaml"},
    {"zsh", "Zsh", "bash"},
}};

// Lowercases language and binary-searches the table. Returns nullptr on miss.
const LanguageName *findLanguage(const std::string &language, std::string &lowerOut) {
  lowerOut = language;
  for (char &c : lowerOut) {
    c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
  }

  auto it =
      std::lower_bound(kLanguageNames.begin(), kLanguageNames.end(), lowerOut.c_str(),
                       [](const LanguageName &entry, const char *key) { return std::strcmp(entry.key, key) < 0; });
  if (it != kLanguageNames.end() && lowerOut == it->key) {
    return &(*it);
  }
  return nullptr;
}

} // namespace

std::string displayNameForLanguage(const std::string &language) {
  if (language.empty()) {
    return "";
  }

  std::string lower;
  if (const LanguageName *entry = findLanguage(language, lower)) {
    return entry->name;
  }

  lower[0] = static_cast<char>(std::toupper(static_cast<unsigned char>(lower[0])));
  return lower;
}

std::string canonicalGrammarId(const std::string &language) {
  if (language.empty()) {
    return "";
  }

  std::string lower;
  if (const LanguageName *entry = findLanguage(language, lower)) {
    return entry->grammar;
  }
  return "";
}

} // namespace Markdown
