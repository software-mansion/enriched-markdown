import XCTest
@testable import EnrichedMarkdownLaTeX

final class LaTeXSpeechTests: XCTestCase {
    private func speak(_ latex: String) -> String {
        LaTeXSpeech.spokenForm(of: latex)
    }

    func testPowersAndIndices() {
        XCTAssertEqual(speak("x^2"), "x squared")
        XCTAssertEqual(speak("x^3"), "x cubed")
        XCTAssertEqual(speak("x^n"), "x to the power n")
        XCTAssertEqual(speak("x^{n+1}"), "x to the power of n plus 1 end power")
        XCTAssertEqual(speak("e^{i\\pi} + 1 = 0"), "e to the power of i pi end power plus 1 equals 0")
        XCTAssertEqual(speak("x_1 \\leq y_{max}"), "x sub 1 less than or equal to y sub max")
        XCTAssertEqual(speak("a_{ij}"), "a sub i j")
        XCTAssertEqual(speak("x_i^2"), "x sub i squared")
    }

    func testFractionsAndRoots() {
        XCTAssertEqual(speak("\\frac{1}{3}"), "1 over 3")
        XCTAssertEqual(speak("\\frac{1}{n^2}"), "1 over n squared")
        XCTAssertEqual(speak("\\frac{a+b}{2}"), "fraction a plus b over 2 end fraction")
        XCTAssertEqual(speak("\\sqrt{2}"), "square root of 2")
        XCTAssertEqual(speak("\\sqrt{a^2+b^2}"), "square root of a squared plus b squared end root")
        XCTAssertEqual(speak("\\sqrt[3]{8}"), "cube root of 8")
        XCTAssertEqual(speak("\\sqrt[n]{x}"), "root n of x")
        XCTAssertEqual(speak("\\binom{n}{k}"), "n choose k")
    }

    func testBigOperatorsWithBounds() {
        XCTAssertEqual(speak("\\int_0^1 x^2 \\, dx = \\frac{1}{3}"), "integral from 0 to 1 of x squared d x equals 1 over 3")
        XCTAssertEqual(speak("\\sum_{n=1}^{\\infty} \\frac{1}{n^2}"), "sum from n equals 1 to infinity of 1 over n squared")
        XCTAssertEqual(speak("\\lim_{x \\to 0} \\frac{\\sin x}{x}"), "limit as x approaches 0 of fraction sine x over x end fraction")
        XCTAssertEqual(speak("\\prod_{i} a_i"), "product from i of a sub i")
        XCTAssertEqual(speak("f: A \\to B"), "f colon A to B")
        XCTAssertEqual(speak("\\int f"), "integral of f")
    }

    func testSymbolsLettersAndText() {
        XCTAssertEqual(speak("\\alpha^2 + \\Pi"), "alpha squared plus capital pi")
        XCTAssertEqual(speak("\\varepsilon > 0"), "epsilon greater than 0")
        XCTAssertEqual(speak("a \\neq b"), "a not equal to b")
        XCTAssertEqual(speak("\\left( a + b \\right)^2"), "open paren a plus b close paren squared")
        XCTAssertEqual(speak("\\left. f \\right|_0^1"), "f vertical bar sub 0 to the power 1")
        XCTAssertEqual(speak("n! \\cdot f'(x)"), "n factorial times f prime open paren x close paren")
        XCTAssertEqual(speak("\\vec{v} \\cdot \\hat{n}"), "vector v times n hat")
        XCTAssertEqual(speak("\\text{speed} = 5 \\, \\mathrm{m/s}"), "speed equals 5 m over s")
        XCTAssertEqual(speak("x \\in \\mathbb{R}"), "x in R")
        XCTAssertEqual(speak("3.14 \\approx \\pi"), "3.14 approximately equal to pi")
    }

    func testUnknownCommandsKeepTheirName() {
        XCTAssertEqual(speak("\\foo{x}"), "foo x")
    }

    func testScriptsReadSubBeforePowerRegardlessOfOrder() {
        XCTAssertEqual(speak("x^2_i"), speak("x_i^2"))
    }

    func testMalformedInputDoesNotCrash() {
        XCTAssertEqual(speak(""), "")
        for latex in ["\\frac{1}", "x^", "}{", "\\", "{", "\\sqrt[", "^_^"] {
            _ = speak(latex)
        }
    }
}
