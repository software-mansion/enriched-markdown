#include <string>
#include <string_view>

#include "LatexSpeech.hpp"
#include "doctest/doctest.h"

namespace {

std::string speak(std::string_view latex) {
  return Markdown::spokenLatex(latex);
}

} // namespace

TEST_CASE("powers and indices") {
  CHECK(speak("x^2") == "x squared");
  CHECK(speak("x^3") == "x cubed");
  CHECK(speak("x^n") == "x to the power n");
  CHECK(speak("x^{n+1}") == "x to the power of n plus 1 end power");
  CHECK(speak("e^{i\\pi} + 1 = 0") == "e to the power of i pi end power plus 1 equals 0");
  CHECK(speak("x_1 \\leq y_{max}") == "x sub 1 less than or equal to y sub max");
  CHECK(speak("a_{ij}") == "a sub i j");
  CHECK(speak("x_i^2") == "x sub i squared");
  CHECK(speak("x^2_i") == speak("x_i^2"));
  CHECK(speak("2^{10}") == "2 to the power 10");
}

TEST_CASE("fractions and roots") {
  CHECK(speak("\\frac{1}{3}") == "1 over 3");
  CHECK(speak("\\frac{1}{n^2}") == "1 over n squared");
  CHECK(speak("\\frac{a+b}{2}") == "fraction a plus b over 2 end fraction");
  CHECK(speak("\\sqrt{2}") == "square root of 2");
  CHECK(speak("\\sqrt{a^2+b^2}") == "square root of a squared plus b squared end root");
  CHECK(speak("\\sqrt[3]{8}") == "cube root of 8");
  CHECK(speak("\\sqrt[n]{x}") == "root n of x");
  CHECK(speak("\\binom{n}{k}") == "n choose k");
}

TEST_CASE("a nested fraction, root or power keeps its closing marker") {
  CHECK(speak("e^{\\frac{x}{2}}") == "e to the power of x over 2 end power");
  CHECK(speak("\\frac{e^x}{2}") == "fraction e to the power x over 2 end fraction");
  CHECK(speak("\\sqrt{\\frac{a}{b}}") == "square root of a over b end root");
  CHECK(speak("\\frac{\\sqrt{a}}{b}") == "fraction square root of a over b end fraction");
  CHECK(speak("\\frac{1}{x^n}") == "fraction 1 over x to the power n end fraction");
  CHECK(speak("x^{a^b}") == "x to the power of a to the power b end power");
  CHECK(speak("\\frac{a_i}{2}") == "a sub i over 2");
}

TEST_CASE("an unbraced argument is one character, as in LaTeX") {
  CHECK(speak("\\frac12") == "1 over 2");
  CHECK(speak("\\frac ab") == "a over b");
  CHECK(speak("x^23") == "x squared 3");
  CHECK(speak("x_12") == "x sub 1 2");
  CHECK(speak("x^{12}") == "x to the power 12");
  CHECK(speak("3.14 \\approx \\pi") == "3.14 approximately equal to pi");
}

TEST_CASE("big operators with bounds") {
  CHECK(speak("\\int_0^1 x^2 \\, dx = \\frac{1}{3}") == "integral from 0 to 1 of x squared d x equals 1 over 3");
  CHECK(speak("\\sum_{n=1}^{\\infty} \\frac{1}{n^2}") == "sum from n equals 1 to infinity of 1 over n squared");
  CHECK(speak("\\lim_{x \\to 0} \\frac{\\sin x}{x}") ==
        "limit as x approaches 0 of fraction sine x over x end fraction");
  CHECK(speak("\\prod_{i} a_i") == "product from i of a sub i");
  CHECK(speak("f: A \\to B") == "f colon A to B");
  CHECK(speak("\\int f") == "integral of f");
  CHECK(speak("\\sum\\limits_{i=1}^n a_i") == "sum from i equals 1 to n of a sub i");
  CHECK(speak("\\int\\limits_0^1 f") == "integral from 0 to 1 of f");
  CHECK(speak("\\int\\nolimits_0^1 f") == "integral from 0 to 1 of f");
}

TEST_CASE("operator names") {
  CHECK(speak("\\operatorname{argmax}_x f(x)") == "argmax sub x f open paren x close paren");
  CHECK(speak("\\operatorname*{argmax}_x f(x)") == "argmax sub x f open paren x close paren");
}

TEST_CASE("environments") {
  CHECK(speak("\\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix}") == "matrix a b next row c d end matrix");
  CHECK(speak("\\begin{bmatrix} 1 \\\\ 0 \\end{bmatrix}") == "matrix 1 next row 0 end matrix");
  CHECK(speak("\\begin{cases} x & \\text{if } x > 0 \\\\ 0 & \\text{otherwise} \\end{cases}") ==
        "cases x if x greater than 0 next case 0 otherwise end cases");
  CHECK(speak("\\begin{aligned} a &= b \\\\ c &= d \\end{aligned}") == "a equals b next line c equals d");
  CHECK(speak("\\begin{align*} a &= b \\\\ c &= d \\end{align*}") == "a equals b next line c equals d");
  CHECK(speak("\\left(\\begin{array}{cc} 1 & 0 \\\\ 0 & 1 \\end{array}\\right)") ==
        "open paren 1 0 next row 0 1 close paren");
  CHECK(speak("\\begin{unknown} a \\\\ b \\end{unknown}") == "a next row b");
  CHECK(speak("a \\\\ b") == "a b");
}

TEST_CASE("symbols, letters and text") {
  CHECK(speak("\\alpha^2 + \\Pi") == "alpha squared plus cap pi");
  CHECK(speak("\\varepsilon > 0") == "epsilon greater than 0");
  CHECK(speak("a \\neq b") == "a not equal to b");
  CHECK(speak("\\left( a + b \\right)^2") == "open paren a plus b close paren squared");
  CHECK(speak("\\left. f \\right|_0^1") == "f vertical bar sub 0 to the power 1");
  CHECK(speak("n! \\cdot f'(x)") == "n factorial times f prime open paren x close paren");
  CHECK(speak("\\vec{v} \\cdot \\hat{n}") == "vector v times n hat");
  CHECK(speak("\\text{speed} = 5 \\, \\mathrm{m/s}") == "speed equals 5 m over s");
  CHECK(speak("x \\in \\mathbb{R}") == "x in R");
  CHECK(speak("\\text{über} \\alpha") == "über alpha");
  CHECK(speak("αβ") == "α β");
}

TEST_CASE("unknown commands keep their name") {
  CHECK(speak("\\foo{x}") == "foo x");
}

TEST_CASE("malformed input does not crash") {
  CHECK(speak("") == "");
  for (const char *latex : {"\\frac{1}", "x^", "}{", "\\", "{", "\\sqrt[", "^_^", "\\begin", "\\begin{", "\\end{x}",
                            "\\\\", "\\operatorname*", "\\frac", "\\sum\\limits", "\\begin{array}"}) {
    CAPTURE(latex);
    CHECK_NOTHROW(speak(latex));
  }
}
