package com.swmansion.enriched.markdown.math

import com.swmansion.enriched.markdown.accessibility.AccessibilityLabels

/** English reading of a LaTeX formula for TalkBack ("x squared over 2" rather than "x caret 2 slash 2"). */
object LatexSpeech {
  fun spokenForm(latex: String): String = Parser(Tokenizer.tokenize(latex)).group(until = null).words.joinToString(" ")
}

fun AccessibilityLabels.mathLabel(latex: String): String {
  val label =
    if (mathEquation.contains("{speech}")) {
      mathEquation.replace("{speech}", LatexSpeech.spokenForm(latex))
    } else {
      mathEquation
    }
  return label.replace("{latex}", latex)
}

private sealed class Token {
  data class Command(
    val name: String,
  ) : Token()

  data class Symbol(
    val text: String,
  ) : Token()

  data class Number(
    val text: String,
  ) : Token()

  data class Letters(
    val text: String,
  ) : Token()
}

private object Tokenizer {
  fun tokenize(latex: String): List<Token> {
    val tokens = mutableListOf<Token>()
    val chars = latex.codePoints().toArray()
    var index = 0
    while (index < chars.size) {
      val char = chars[index]
      when {
        char == '\\'.code -> {
          index++
          if (index >= chars.size) break
          val end = if (Character.isLetter(chars[index])) runEnd(chars, index) { Character.isLetter(it) } else index + 1
          tokens.add(Token.Command(String(chars, index, end - index)))
          index = end
        }

        Character.isDigit(char) -> {
          val end = runEnd(chars, index) { Character.isDigit(it) || it == '.'.code }
          tokens.add(Token.Number(String(chars, index, end - index)))
          index = end
        }

        Character.isLetter(char) -> {
          val end = runEnd(chars, index) { Character.isLetter(it) }
          tokens.add(Token.Letters(String(chars, index, end - index)))
          index = end
        }

        Character.isWhitespace(char) -> {
          index++
        }

        else -> {
          tokens.add(Token.Symbol(String(chars, index, 1)))
          index++
        }
      }
    }
    return tokens
  }

  private fun runEnd(
    chars: IntArray,
    start: Int,
    predicate: (Int) -> Boolean,
  ): Int {
    var end = start
    while (end < chars.size && predicate(chars[end])) end++
    return end
  }
}

private class Parser(
  private val tokens: List<Token>,
) {
  class Argument(
    val words: List<String> = emptyList(),
    val itemCount: Int = 0,
  ) {
    val isSimple: Boolean get() = itemCount == 1

    fun closed(marker: String): List<String> = if (itemCount > 1) words + marker else words
  }

  private enum class Mode { MATH, TEXT, LIMIT }

  private var position = 0
  private var mode = Mode.MATH
  private val current: Token? get() = tokens.getOrNull(position)

  fun group(until: Token?): Argument {
    val words = mutableListOf<String>()
    var itemCount = 0
    while (current != null && current != until) {
      val itemWords = item()
      if (itemWords.isNotEmpty()) {
        words += itemWords
        itemCount++
      }
    }
    position++
    return Argument(words, itemCount)
  }

  private fun item(): List<String> {
    val base = argument().words
    val (sub, sup) = scripts()
    return base + index(sub) + power(sup)
  }

  private fun argument(): Argument {
    val token = current ?: return Argument()
    position++
    if (token == Token.Symbol("{")) return group(Token.Symbol("}"))
    val words = atom(token)
    return Argument(words, if (words.isEmpty()) 0 else 1)
  }

  private fun argument(mode: Mode): Argument {
    val outer = this.mode
    this.mode = mode
    val parsed = argument()
    this.mode = outer
    return parsed
  }

  private fun scripts(): Pair<Argument?, Argument?> {
    var sub: Argument? = null
    var sup: Argument? = null
    var script = current
    while (script == Token.Symbol("^") || script == Token.Symbol("_")) {
      position++
      if (script == Token.Symbol("^")) sup = argument() else sub = argument()
      script = current
    }
    return sub to sup
  }

  private fun atom(token: Token): List<String> =
    when (token) {
      is Token.Symbol -> {
        spoken(SYMBOL_WORDS[token.text], token.text)
      }

      is Token.Number -> {
        listOf(token.text)
      }

      // Up to two letters are juxtaposed variables ("dx"); longer runs are words ("max").
      is Token.Letters -> {
        val letters = token.text.codePointStrings()
        if (mode == Mode.TEXT || letters.size > 2) listOf(token.text) else letters
      }

      is Token.Command -> {
        command(token.name)
      }
    }

  private fun command(name: String): List<String> =
    when (name) {
      "frac", "dfrac", "tfrac" -> {
        val numerator = argument()
        fraction(numerator, argument())
      }

      "binom" -> {
        val top = argument()
        top.words + "choose" + argument().words
      }

      "sqrt" -> {
        val degree =
          if (current == Token.Symbol("[")) {
            position++
            group(Token.Symbol("]"))
          } else {
            Argument()
          }
        root(degree, argument())
      }

      "text", "textrm", "textbf", "textit", "mathrm", "mathbf", "mathit", "mathsf", "mathtt", "operatorname", "mbox" -> {
        argument(Mode.TEXT).words
      }

      "mathbb", "mathcal", "mathfrak", "boldsymbol", "bm" -> {
        argument().words
      }

      "vec" -> {
        listOf("vector") + argument().words
      }

      "hat", "bar", "overline", "tilde", "dot", "ddot" -> {
        argument().words + (DECORATIONS[name] ?: name)
      }

      "left", "right" -> {
        // The delimiter that follows reads as a plain symbol; "." is the invisible one.
        if (current == Token.Symbol(".")) position++
        emptyList()
      }

      "sum", "prod", "int", "iint", "oint", "lim", "bigcup", "bigcap" -> {
        bigOperator(name)
      }

      "to", "rightarrow" -> {
        if (mode == Mode.LIMIT) listOf("approaches") else spoken(COMMAND_WORDS[name], name)
      }

      else -> {
        spoken(COMMAND_WORDS[name], name)
      }
    }

  private fun bigOperator(name: String): List<String> {
    val outer = mode
    if (name == "lim") mode = Mode.LIMIT
    val (lower, upper) = scripts()
    mode = outer

    val words = mutableListOf(BIG_OPERATORS[name] ?: name)
    if (lower != null) words += listOf(if (name == "lim") "as" else "from") + lower.words
    if (upper != null) words += listOf("to") + upper.words
    return words + "of"
  }

  private fun power(exponent: Argument?): List<String> {
    if (exponent == null || exponent.words.isEmpty()) return emptyList()
    return when {
      exponent.words == listOf("2") -> listOf("squared")
      exponent.words == listOf("3") -> listOf("cubed")
      exponent.isSimple -> listOf("to the power") + exponent.words
      else -> listOf("to the power of") + exponent.closed("end power")
    }
  }

  private fun index(sub: Argument?): List<String> {
    if (sub == null || sub.words.isEmpty()) return emptyList()
    return listOf("sub") + sub.closed("end sub")
  }

  private fun fraction(
    numerator: Argument,
    denominator: Argument,
  ): List<String> {
    if (numerator.isSimple && denominator.isSimple) return numerator.words + "over" + denominator.words
    return listOf("fraction") + numerator.words + "over" + denominator.words + "end fraction"
  }

  private fun root(
    degree: Argument,
    radicand: Argument,
  ): List<String> {
    val body = radicand.closed("end root")
    return when {
      degree.words.isEmpty() -> listOf("square root of") + body
      degree.words == listOf("3") -> listOf("cube root of") + body
      else -> listOf("root") + degree.words + "of" + body
    }
  }

  /** An empty mapping is silent (spacing and layout), a missing one reads the fallback. */
  private fun spoken(
    word: String?,
    fallback: String,
  ): List<String> =
    when {
      word == null -> listOf(fallback)
      word.isEmpty() -> emptyList()
      else -> listOf(word)
    }

  private fun String.codePointStrings(): List<String> = codePoints().toArray().map { String(intArrayOf(it), 0, 1) }

  private companion object {
    val SYMBOL_WORDS =
      mapOf(
        "+" to "plus",
        "-" to "minus",
        "=" to "equals",
        "<" to "less than",
        ">" to "greater than",
        "/" to "over",
        "*" to "times",
        "!" to "factorial",
        "'" to "prime",
        "," to "comma",
        "." to "point",
        "(" to "open paren",
        ")" to "close paren",
        "[" to "open bracket",
        "]" to "close bracket",
        "|" to "vertical bar",
        ":" to "colon",
        ";" to "",
        "&" to "",
        "~" to "",
        "^" to "",
        "_" to "",
        "}" to "",
      )

    val BIG_OPERATORS =
      mapOf(
        "prod" to "product",
        "int" to "integral",
        "iint" to "double integral",
        "oint" to "contour integral",
        "lim" to "limit",
        "bigcup" to "union",
        "bigcap" to "intersection",
      )

    val DECORATIONS = mapOf("overline" to "bar", "ddot" to "double dot")

    val GREEK =
      listOf(
        "alpha",
        "beta",
        "gamma",
        "delta",
        "epsilon",
        "varepsilon",
        "zeta",
        "eta",
        "theta",
        "vartheta",
        "iota",
        "kappa",
        "lambda",
        "mu",
        "nu",
        "xi",
        "pi",
        "varpi",
        "rho",
        "varrho",
        "sigma",
        "varsigma",
        "tau",
        "upsilon",
        "phi",
        "varphi",
        "chi",
        "psi",
        "omega",
      )

    val COMMAND_WORDS: Map<String, String> =
      mapOf(
        "," to "",
        ";" to "",
        ":" to "",
        "!" to "",
        " " to "",
        "\\" to "",
        "quad" to "",
        "qquad" to "",
        "displaystyle" to "",
        "textstyle" to "",
        "nonumber" to "",
        "{" to "open brace",
        "}" to "close brace",
        "|" to "double bar",
        "%" to "percent",
        "_" to "underscore",
        "infty" to "infinity",
        "hbar" to "h bar",
        "cdots" to "dot dot dot",
        "ldots" to "dot dot dot",
        "dots" to "dot dot dot",
        "vdots" to "dot dot dot",
        "degree" to "degrees",
        "emptyset" to "empty set",
        "neq" to "not equal to",
        "ne" to "not equal to",
        "leq" to "less than or equal to",
        "le" to "less than or equal to",
        "geq" to "greater than or equal to",
        "ge" to "greater than or equal to",
        "approx" to "approximately equal to",
        "equiv" to "is equivalent to",
        "sim" to "similar to",
        "propto" to "proportional to",
        "cdot" to "times",
        "div" to "divided by",
        "pm" to "plus or minus",
        "mp" to "minus or plus",
        "rightarrow" to "to",
        "leftarrow" to "from",
        "Rightarrow" to "implies",
        "Leftrightarrow" to "if and only if",
        "mapsto" to "maps to",
        "notin" to "not in",
        "subset" to "subset of",
        "subseteq" to "subset of or equal to",
        "supset" to "superset of",
        "cup" to "union",
        "cap" to "intersection",
        "forall" to "for all",
        "exists" to "there exists",
        "perp" to "perpendicular to",
        "parallel" to "parallel to",
        "mid" to "given",
        "circ" to "composed with",
        "sin" to "sine",
        "cos" to "cosine",
        "tan" to "tangent",
        "cot" to "cotangent",
        "sec" to "secant",
        "csc" to "cosecant",
        "arcsin" to "arc sine",
        "arccos" to "arc cosine",
        "arctan" to "arc tangent",
        "sinh" to "hyperbolic sine",
        "cosh" to "hyperbolic cosine",
        "tanh" to "hyperbolic tangent",
        "ln" to "natural log",
        "exp" to "exponential",
        "det" to "determinant",
        "dim" to "dimension",
        "sup" to "supremum",
        "inf" to "infimum",
        "ker" to "kernel",
        "Re" to "real part",
        "Im" to "imaginary part",
      ) +
        GREEK.flatMap { letter ->
          val spoken = letter.removePrefix("var")
          listOf(letter to spoken, letter.replaceFirstChar { it.uppercase() } to "capital $spoken")
        }
  }
}
