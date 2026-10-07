package com.swmansion.enriched.markdown.syntaxhighlighting

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class SyntaxHighlighterNativeTest {
  private data class Token(
    val start: Int,
    val end: Int,
    val type: Int,
  )

  private fun highlight(
    code: String,
    language: String,
  ): List<Token> {
    val flat = SyntaxHighlighterNative.highlight(code.toByteArray(Charsets.UTF_8), language)
    assertEquals("triplets", 0, flat.size % 3)
    val tokens = flat.toList().chunked(3).map { (start, end, type) -> Token(start, end, type) }
    assertWellFormed(code, tokens)
    return tokens
  }

  private fun assertWellFormed(
    code: String,
    tokens: List<Token>,
  ) {
    var previousEnd = 0
    for (token in tokens) {
      assertTrue("ordered, non-overlapping: $tokens", token.start >= previousEnd)
      assertTrue("non-empty: $token", token.end > token.start)
      assertTrue("within the UTF-16 length ${code.length}: $token", token.end <= code.length)
      assertTrue("known token type: $token", token.type in 0 until SyntaxHighlighterNative.TOKEN_TYPE_COUNT)
      previousEnd = token.end
    }
  }

  private fun List<Token>.typeOf(
    code: String,
    text: String,
  ): Int? {
    val start = code.indexOf(text)
    return firstOrNull { it.start == start && it.end == start + text.length }?.type
  }

  @Test
  fun highlightsPython() {
    val code = "def add(a, b):\n    return a + 42  # sum\n"
    val tokens = highlight(code, "python")

    assertEquals(KEYWORD, tokens.typeOf(code, "def"))
    assertEquals(FUNCTION, tokens.typeOf(code, "add"))
    assertEquals(KEYWORD, tokens.typeOf(code, "return"))
    assertEquals(OPERATOR, tokens.typeOf(code, "+"))
    assertEquals(NUMBER, tokens.typeOf(code, "42"))
    assertEquals(COMMENT, tokens.typeOf(code, "# sum"))
  }

  @Test
  fun highlightsJava() {
    val code = "class Main {\n  int x = 1; // note\n}\n"
    val tokens = highlight(code, "java")

    assertEquals(KEYWORD, tokens.typeOf(code, "class"))
    assertEquals(TYPE, tokens.typeOf(code, "int"))
    assertEquals(NUMBER, tokens.typeOf(code, "1"))
    assertEquals(COMMENT, tokens.typeOf(code, "// note"))
  }

  @Test
  fun resolvesFenceAliasesCaseInsensitively() {
    val code = "const x = 1;"

    assertEquals(highlight(code, "javascript"), highlight(code, "js"))
    assertEquals(highlight(code, "javascript"), highlight(code, "JS"))
  }

  @Test
  fun everyCompiledGrammarProducesTokens() {
    val samples =
      mapOf(
        "bash" to "echo \"hi\" # c",
        "c" to "int main(void) { return 0; }",
        "css" to "a { color: red; }",
        "go" to "func main() { return }",
        "html" to "<div class=\"x\">hi</div>",
        "java" to "return 1;",
        "javascript" to "const x = \"s\";",
        "json" to "{\"a\": 1}",
        "markdown" to "# Title",
        "python" to "x = 1",
        "rust" to "fn main() { let x = 1; }",
        "tsx" to "const a = <div />;",
        "typescript" to "let x: number = 1;",
        "yaml" to "key: value",
      )

    for ((language, code) in samples) {
      assertTrue("$language yields tokens", highlight(code, language).isNotEmpty())
    }
  }

  @Test
  fun offsetsAreUtf16CodeUnits() {
    // 2-, 3- and 4-byte UTF-8 sequences; the emoji is a surrogate pair in UTF-16.
    val code = "s = \"😀é€\"  # done 🚀"
    val tokens = highlight(code, "python")

    val string = "\"😀é€\""
    assertEquals(STRING, tokens.typeOf(code, string))
    val comment = code.substring(code.indexOf('#'))
    assertEquals(COMMENT, tokens.typeOf(code, comment))
    assertEquals(code.length, tokens.last().end)
  }

  @Test
  fun unknownLanguageReturnsEmpty() {
    assertTrue(highlight("fun main() {}", "kotlin").isEmpty())
    assertTrue(highlight("x = 1", "no-such-language").isEmpty())
    assertTrue(highlight("x = 1", "").isEmpty())
  }

  @Test
  fun emptyCodeReturnsEmpty() {
    assertTrue(highlight("", "python").isEmpty())
  }

  @Test
  fun respectsByteCap() {
    val atCap = "# " + "a".repeat(MAX_BYTES - 2)
    assertTrue(highlight(atCap, "python").isNotEmpty())
    assertTrue(highlight(atCap + "a", "python").isEmpty())
  }

  @Test
  fun byteCapCountsUtf8BytesNotChars() {
    // 12,800 emoji: 25,602 UTF-16 units in all, but 51,202 UTF-8 bytes, past the cap.
    val code = "# " + "😀".repeat(MAX_BYTES / 4)
    assertTrue(code.length < MAX_BYTES)
    assertTrue(highlight(code, "python").isEmpty())
  }

  @Test
  fun respectsLineCap() {
    val atCap = List(MAX_LINES) { "x = 1" }.joinToString("\n")
    assertTrue(highlight(atCap, "python").isNotEmpty())
    assertTrue(highlight(atCap + "\n", "python").isEmpty())
  }

  private companion object {
    // HighlightTokenType values from CodeBlockHighlighter.hpp.
    const val KEYWORD = 0
    const val OPERATOR = 1
    const val STRING = 3
    const val NUMBER = 4
    const val COMMENT = 6
    const val FUNCTION = 7
    const val TYPE = 8

    // Caps from CodeBlockHighlighter.cpp.
    const val MAX_BYTES = 50 * 1024
    const val MAX_LINES = 2000
  }
}
