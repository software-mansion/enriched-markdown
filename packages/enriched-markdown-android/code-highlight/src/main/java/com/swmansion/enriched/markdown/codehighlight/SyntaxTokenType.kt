package com.swmansion.enriched.markdown.codehighlight

/**
 * What a highlighted span of code is, after tree-sitter's standard highlight capture names
 * flattened to one level. Declared in the native seam's order: a token's type crosses JNI as its
 * [ordinal].
 */
enum class SyntaxTokenType {
  KEYWORD,
  OPERATOR,
  PUNCTUATION,
  STRING,
  NUMBER,
  CONSTANT,
  COMMENT,
  FUNCTION,
  TYPE,
  VARIABLE,
  PROPERTY,
  TAG,
  ATTRIBUTE,
  EMBEDDED,
}
