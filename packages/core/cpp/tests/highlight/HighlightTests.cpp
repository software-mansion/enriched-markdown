#include <cstdint>
#include <string>
#include <vector>

#include "CodeBlockHighlighter.hpp"
#include "CodeBlockLanguages.hpp"
#include "doctest/doctest.h"

namespace Markdown {
bool operator==(const HighlightToken &a, const HighlightToken &b) {
  return a.start == b.start && a.end == b.end && a.type == b.type;
}
} // namespace Markdown

using Markdown::highlightCode;
using Markdown::HighlightToken;
using Markdown::HighlightTokenType;

namespace {

// Encodes code as UTF-16 so token ranges, which are UTF-16 offsets, can be
// sliced back into text and compared as UTF-8.
std::u16string toUtf16(const std::string &utf8) {
  std::u16string out;
  size_t i = 0;
  while (i < utf8.size()) {
    unsigned char c = static_cast<unsigned char>(utf8[i]);
    uint32_t cp;
    size_t len;
    if (c < 0x80) {
      cp = c;
      len = 1;
    } else if ((c >> 5) == 0x6) {
      cp = c & 0x1F;
      len = 2;
    } else if ((c >> 4) == 0xE) {
      cp = c & 0x0F;
      len = 3;
    } else {
      cp = c & 0x07;
      len = 4;
    }
    for (size_t k = 1; k < len; ++k) {
      cp = (cp << 6) | (static_cast<unsigned char>(utf8[i + k]) & 0x3F);
    }
    if (cp >= 0x10000) {
      cp -= 0x10000;
      out.push_back(static_cast<char16_t>(0xD800 + (cp >> 10)));
      out.push_back(static_cast<char16_t>(0xDC00 + (cp & 0x3FF)));
    } else {
      out.push_back(static_cast<char16_t>(cp));
    }
    i += len;
  }
  return out;
}

std::string toUtf8(const std::u16string &utf16) {
  std::string out;
  for (size_t i = 0; i < utf16.size(); ++i) {
    uint32_t cp = utf16[i];
    if (cp >= 0xD800 && cp < 0xDC00 && i + 1 < utf16.size()) {
      cp = 0x10000 + ((cp - 0xD800) << 10) + (utf16[++i] - 0xDC00);
    }
    if (cp < 0x80) {
      out.push_back(static_cast<char>(cp));
    } else if (cp < 0x800) {
      out.push_back(static_cast<char>(0xC0 | (cp >> 6)));
      out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
    } else if (cp < 0x10000) {
      out.push_back(static_cast<char>(0xE0 | (cp >> 12)));
      out.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
      out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
    } else {
      out.push_back(static_cast<char>(0xF0 | (cp >> 18)));
      out.push_back(static_cast<char>(0x80 | ((cp >> 12) & 0x3F)));
      out.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
      out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
    }
  }
  return out;
}

// The text of every token of type, in order.
std::vector<std::string> texts(const std::string &code, const std::string &language, HighlightTokenType type) {
  const std::u16string units = toUtf16(code);
  std::vector<std::string> out;
  for (const HighlightToken &token : highlightCode(code, language)) {
    if (token.type == type) {
      out.push_back(toUtf8(units.substr(token.start, token.end - token.start)));
    }
  }
  return out;
}

bool contains(const std::vector<std::string> &values, const std::string &value) {
  for (const std::string &v : values) {
    if (v == value) {
      return true;
    }
  }
  return false;
}

void checkOrderedAndInBounds(const std::string &code, const std::string &language) {
  const std::vector<HighlightToken> tokens = highlightCode(code, language);
  const uint32_t length = static_cast<uint32_t>(toUtf16(code).size());
  REQUIRE_FALSE(tokens.empty());
  uint32_t previousEnd = 0;
  for (const HighlightToken &token : tokens) {
    CHECK(token.start >= previousEnd);
    CHECK(token.end > token.start);
    CHECK(token.end <= length);
    previousEnd = token.end;
  }
}

} // namespace

TEST_CASE("fence aliases resolve to their grammar and display name") {
  struct Alias {
    const char *fence;
    const char *grammar;
    const char *name;
  };
  const Alias aliases[] = {
      {"kotlin", "kotlin", "Kotlin"}, {"kt", "kotlin", "Kotlin"},        {"KTS", "kotlin", "Kotlin"},
      {"swift", "swift", "Swift"},    {"dart", "dart", "Dart"},          {"sql", "sql", "SQL"},
      {"mysql", "sql", "MySQL"},      {"postgres", "sql", "PostgreSQL"}, {"postgresql", "sql", "PostgreSQL"},
      {"pgsql", "sql", "PostgreSQL"}, {"sqlite", "sql", "SQLite"},       {"diff", "diff", "Diff"},
      {"patch", "diff", "Patch"},     {"Diff", "diff", "Diff"},
  };
  for (const Alias &alias : aliases) {
    CAPTURE(alias.fence);
    CHECK(Markdown::canonicalGrammarId(alias.fence) == alias.grammar);
    CHECK(Markdown::displayNameForLanguage(alias.fence) == alias.name);
  }
}

TEST_CASE("languages without a grammar stay plain") {
  CHECK(highlightCode("let x = 1", "klingon").empty());
  CHECK(highlightCode("let x = 1", "").empty());
  CHECK(highlightCode("[a]\nb = 1", "toml").empty());
  CHECK(Markdown::displayNameForLanguage("klingon") == "Klingon");
  // A grammar the language table knows but this build did not compile.
  CHECK(highlightCode("x := 1", "go").empty());
}

TEST_CASE("kotlin") {
  const std::string code =
      "import kotlin.math.abs\n"
      "fun greet(name: String): String {\n"
      "    val n = 42\n"
      "    if (n > 0) { for (i in 1..n) { try { abs(i) } catch (e: Exception) {} } }\n"
      "    return \"hi $name\" // note\n"
      "}";
  CHECK(contains(texts(code, "kotlin", HighlightTokenType::Keyword), "fun"));
  CHECK(contains(texts(code, "kotlin", HighlightTokenType::Keyword), "val"));
  for (const char *keyword : {"import", "if", "for", "try", "catch"}) {
    CHECK(contains(texts(code, "kotlin", HighlightTokenType::Keyword), keyword));
  }
  CHECK(contains(texts(code, "kotlin", HighlightTokenType::Function), "greet"));
  CHECK(contains(texts(code, "kotlin", HighlightTokenType::Type), "String"));
  CHECK(contains(texts(code, "kotlin", HighlightTokenType::Number), "42"));
  CHECK(contains(texts(code, "kotlin", HighlightTokenType::Comment), "// note"));
  CHECK(highlightCode(code, "kt") == highlightCode(code, "kotlin"));
  checkOrderedAndInBounds(code, "kotlin");
}

TEST_CASE("swift") {
  const std::string code =
      "func greet(name: String) -> String {\n"
      "    let n = 42\n"
      "    return \"hi\" // note\n"
      "}";
  CHECK(contains(texts(code, "swift", HighlightTokenType::Keyword), "func"));
  CHECK(contains(texts(code, "swift", HighlightTokenType::Keyword), "let"));
  CHECK(contains(texts(code, "swift", HighlightTokenType::Keyword), "return"));
  CHECK(contains(texts(code, "swift", HighlightTokenType::Function), "greet"));
  CHECK(contains(texts(code, "swift", HighlightTokenType::Number), "42"));
  CHECK(contains(texts(code, "swift", HighlightTokenType::Comment), "// note"));
  checkOrderedAndInBounds(code, "swift");
}

TEST_CASE("dart") {
  const std::string code =
      "import 'dart:math';\n"
      "class Greeter {}\n"
      "void main() {\n"
      "  var n = 42;\n"
      "  if (n > 0) { for (var i = 0; i < n; i++) { try {} catch (e) {} } }\n"
      "  print('hi'); // note\n"
      "}";
  CHECK(contains(texts(code, "dart", HighlightTokenType::Keyword), "var"));
  for (const char *keyword : {"import", "if", "for", "try", "catch"}) {
    CHECK(contains(texts(code, "dart", HighlightTokenType::Keyword), keyword));
  }
  CHECK(contains(texts(code, "dart", HighlightTokenType::Function), "main"));
  CHECK(contains(texts(code, "dart", HighlightTokenType::Type), "Greeter"));
  CHECK(contains(texts(code, "dart", HighlightTokenType::Type), "void"));
  CHECK(contains(texts(code, "dart", HighlightTokenType::String), "'hi'"));
  CHECK(contains(texts(code, "dart", HighlightTokenType::Number), "42"));
  CHECK(contains(texts(code, "dart", HighlightTokenType::Comment), "// note"));
  checkOrderedAndInBounds(code, "dart");
}

TEST_CASE("sql") {
  const std::string code = "SELECT id, name FROM users WHERE id = 42 AND name = 'a'; -- note";
  CHECK(contains(texts(code, "sql", HighlightTokenType::Keyword), "SELECT"));
  CHECK(contains(texts(code, "sql", HighlightTokenType::Keyword), "FROM"));
  CHECK(contains(texts(code, "sql", HighlightTokenType::Keyword), "WHERE"));
  CHECK(contains(texts(code, "sql", HighlightTokenType::Number), "42"));
  CHECK(contains(texts(code, "sql", HighlightTokenType::Comment), "-- note"));
  CHECK(highlightCode(code, "postgresql") == highlightCode(code, "sql"));
  checkOrderedAndInBounds(code, "sql");
}

TEST_CASE("diff colors file headers, hunk ranges, additions and deletions") {
  const std::string code =
      "diff --git a/app.kt b/app.kt\n"
      "index 83db48f..bf269f4 100644\n"
      "--- a/app.kt\n"
      "+++ b/app.kt\n"
      "@@ -1,4 +1,4 @@ fun main() {\n"
      " context\n"
      "-removed\n"
      "--- removed, not a header\n"
      "+added\n"
      "+++ added, not a header\n"
      "\\ No newline at end of file";
  using T = HighlightTokenType;
  CHECK(texts(code, "diff", T::Constant) == std::vector<std::string>{"diff --git a/app.kt b/app.kt",
                                                                     "index 83db48f..bf269f4 100644", "--- a/app.kt",
                                                                     "+++ b/app.kt"});
  CHECK(texts(code, "diff", T::Function) == std::vector<std::string>{"@@ -1,4 +1,4 @@"});
  CHECK(texts(code, "diff", T::Deleted) == std::vector<std::string>{"-removed", "--- removed, not a header"});
  CHECK(texts(code, "diff", T::Inserted) == std::vector<std::string>{"+added", "+++ added, not a header"});
  CHECK(texts(code, "diff", T::Comment) == std::vector<std::string>{"\\ No newline at end of file"});
  CHECK(highlightCode(code, "patch") == highlightCode(code, "diff"));
  checkOrderedAndInBounds(code, "diff");

  // Context lines and the hunk's trailing function context keep the base color.
  for (const HighlightToken &token : highlightCode(code, "diff")) {
    const std::string text = toUtf8(toUtf16(code).substr(token.start, token.end - token.start));
    CHECK(text.find("context") == std::string::npos);
    CHECK(text.find("fun main") == std::string::npos);
  }
}

TEST_CASE("diff without hunk headers still colors changed lines") {
  const std::string code = "--- before\n+++ after\n unchanged\n-old\n+new\r\n+\n-\n";
  using T = HighlightTokenType;
  CHECK(texts(code, "diff", T::Constant) == std::vector<std::string>{"--- before", "+++ after"});
  CHECK(texts(code, "diff", T::Deleted) == std::vector<std::string>{"-old", "-"});
  CHECK(texts(code, "diff", T::Inserted) == std::vector<std::string>{"+new", "+"});
}

TEST_CASE("token ranges are UTF-16 offsets") {
  using T = HighlightTokenType;
  const std::string diff = "-caf\xC3\xA9 \xF0\x9F\x8E\x89\n+caf\xC3\xA9 \xF0\x9F\x9A\x80 done\n same";
  CHECK(texts(diff, "diff", T::Deleted) == std::vector<std::string>{"-caf\xC3\xA9 \xF0\x9F\x8E\x89"});
  CHECK(texts(diff, "diff", T::Inserted) == std::vector<std::string>{"+caf\xC3\xA9 \xF0\x9F\x9A\x80 done"});

  const std::string kotlin = "val s = \"\xF0\x9F\x8E\x89\xC3\xA9\" // \xF0\x9F\x8E\x89\nval n = 1";
  CHECK(contains(texts(kotlin, "kotlin", T::Comment), "// \xF0\x9F\x8E\x89"));
  CHECK(contains(texts(kotlin, "kotlin", T::Number), "1"));
  checkOrderedAndInBounds(kotlin, "kotlin");
}

TEST_CASE("code past the size caps renders plain") {
  const std::string line = "+val x = 1\n";
  std::string underCap;
  std::string overLineCap;
  for (int i = 0; i < 1000; ++i) {
    underCap += line;
  }
  for (int i = 0; i < 2500; ++i) {
    overLineCap += line;
  }
  const std::string overByteCap(50 * 1024 + 1, 'x');

  for (const char *language : {"diff", "kotlin", "sql"}) {
    CAPTURE(language);
    CHECK_FALSE(highlightCode(underCap, language).empty());
    CHECK(highlightCode(overLineCap, language).empty());
    CHECK(highlightCode("+" + overByteCap, language).empty());
  }
}
