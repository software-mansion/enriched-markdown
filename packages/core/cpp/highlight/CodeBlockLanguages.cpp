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
};

// Sorted by key; displayNameForLanguage binary-searches this table.
constexpr std::array<LanguageName, 44> kLanguageNames{{
    {"bash", "Bash"},
    {"c", "C"},
    {"cc", "C++"},
    {"cpp", "C++"},
    {"cs", "C#"},
    {"csharp", "C#"},
    {"css", "CSS"},
    {"cxx", "C++"},
    {"dockerfile", "Dockerfile"},
    {"go", "Go"},
    {"golang", "Go"},
    {"graphql", "GraphQL"},
    {"html", "HTML"},
    {"java", "Java"},
    {"javascript", "JavaScript"},
    {"js", "JavaScript"},
    {"json", "JSON"},
    {"jsx", "JSX"},
    {"kotlin", "Kotlin"},
    {"kt", "Kotlin"},
    {"markdown", "Markdown"},
    {"md", "Markdown"},
    {"objc", "Objective-C"},
    {"objectivec", "Objective-C"},
    {"php", "PHP"},
    {"py", "Python"},
    {"python", "Python"},
    {"rb", "Ruby"},
    {"ruby", "Ruby"},
    {"rs", "Rust"},
    {"rust", "Rust"},
    {"scss", "SCSS"},
    {"sh", "Shell"},
    {"shell", "Shell"},
    {"sql", "SQL"},
    {"swift", "Swift"},
    {"toml", "TOML"},
    {"ts", "TypeScript"},
    {"tsx", "TSX"},
    {"typescript", "TypeScript"},
    {"xml", "XML"},
    {"yaml", "YAML"},
    {"yml", "YAML"},
    {"zsh", "Zsh"},
}};

} // namespace

std::string displayNameForLanguage(const std::string &language) {
  if (language.empty()) {
    return "";
  }

  std::string lower = language;
  for (char &c : lower) {
    c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
  }

  auto it =
      std::lower_bound(kLanguageNames.begin(), kLanguageNames.end(), lower.c_str(),
                       [](const LanguageName &entry, const char *key) { return std::strcmp(entry.key, key) < 0; });
  if (it != kLanguageNames.end() && lower == it->key) {
    return it->name;
  }

  lower[0] = static_cast<char>(std::toupper(static_cast<unsigned char>(lower[0])));
  return lower;
}

} // namespace Markdown
