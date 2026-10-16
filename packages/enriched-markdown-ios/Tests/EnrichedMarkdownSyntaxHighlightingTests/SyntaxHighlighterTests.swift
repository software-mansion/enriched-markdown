import XCTest
@testable import EnrichedMarkdownSyntaxHighlighting

final class SyntaxHighlighterTests: XCTestCase {
    private func texts(of type: SyntaxTokenType, in code: String, language: String) -> [String] {
        SyntaxHighlighter.tokens(in: code, language: language)
            .filter { $0.type == type }
            .map { (code as NSString).substring(with: $0.range) }
    }

    func testTokenizesByGrammar() {
        let code = """
        def greet(name):
            return "hi"  # note
        """

        XCTAssertEqual(texts(of: .keyword, in: code, language: "python"), ["def", "return"])
        XCTAssertEqual(texts(of: .function, in: code, language: "python"), ["greet"])
        XCTAssertEqual(texts(of: .string, in: code, language: "python"), ["\"hi\""])
        XCTAssertEqual(texts(of: .comment, in: code, language: "python"), ["# note"])
    }

    func testTokensAreOrderedAndDisjoint() {
        let code = "const total = items.map((item) => item.price * 2).length;"
        let tokens = SyntaxHighlighter.tokens(in: code, language: "javascript")

        XCTAssertFalse(tokens.isEmpty)
        for (previous, next) in zip(tokens, tokens.dropFirst()) {
            XCTAssertLessThanOrEqual(NSMaxRange(previous.range), next.range.location)
        }
        XCTAssertLessThanOrEqual(tokens.last.map { NSMaxRange($0.range) } ?? 0, (code as NSString).length)
        XCTAssertEqual(SyntaxHighlighter.tokens(in: code, language: "javascript"), tokens, "cached tokens are the same")
    }

    func testInfoStringAliasesShareAGrammar() {
        let code = "const answer = 42;"
        let tokens = SyntaxHighlighter.tokens(in: code, language: "javascript")

        XCTAssertFalse(tokens.isEmpty)
        XCTAssertEqual(SyntaxHighlighter.tokens(in: code, language: "js"), tokens)
        XCTAssertEqual(SyntaxHighlighter.tokens(in: code, language: "JS"), tokens, "info strings match case-insensitively")
    }

    func testLanguageIsPartOfTheCacheKey() {
        let code = "x = 1  # note"
        let python = SyntaxHighlighter.tokens(in: code, language: "python")
        let javascript = SyntaxHighlighter.tokens(in: code, language: "javascript")

        XCTAssertTrue(python.contains { $0.type == .comment })
        XCTAssertNotEqual(python, javascript)
    }

    func testEveryBundledGrammarHighlights() {
        let samples: [String: String] = [
            "json": "{\"key\": [1, true, null]}",
            "html": "<p class=\"note\">Hi</p>",
            "css": "a:hover { color: #fff; }",
            "markdown": "# Title\n\n- item",
            "yaml": "name: value\nlist:\n  - 1",
            "go": "func main() { return }",
            "java": "class A { int x = 1; }",
            "javascript": "const x = () => 1;",
            "python": "def f():\n    return 1",
            "c": "int main(void) { return 0; }",
            "rust": "fn main() { let x = 1; }",
            "bash": "echo \"hi\" # note",
            "typescript": "const x: number = 1;",
            "tsx": "const a = <div className=\"x\">hi</div>;"
        ]

        for (language, code) in samples {
            XCTAssertFalse(SyntaxHighlighter.tokens(in: code, language: language).isEmpty, "no tokens for \(language)")
        }
    }

    func testTypeScriptInheritsJavaScriptCaptures() {
        let code = "const label: string = \"a\"; // note"

        XCTAssertEqual(texts(of: .keyword, in: code, language: "ts"), ["const"])
        XCTAssertEqual(texts(of: .string, in: code, language: "ts"), ["\"a\""])
        XCTAssertEqual(texts(of: .comment, in: code, language: "ts"), ["// note"])
    }

    func testRangesAreUTF16Offsets() {
        let code = "x = \"🎉é\"  # 🎉\nimport os"

        XCTAssertEqual(texts(of: .string, in: code, language: "python"), ["\"🎉é\""])
        XCTAssertEqual(texts(of: .comment, in: code, language: "python"), ["# 🎉"])
        XCTAssertEqual(texts(of: .keyword, in: code, language: "python"), ["import"])
    }

    func testUnknownLanguageHasNoTokens() {
        XCTAssertTrue(SyntaxHighlighter.tokens(in: "let x = 1", language: "klingon").isEmpty)
        XCTAssertTrue(SyntaxHighlighter.tokens(in: "let x = 1", language: "").isEmpty)
    }

    func testEmptyCodeHasNoTokens() {
        XCTAssertTrue(SyntaxHighlighter.tokens(in: "", language: "python").isEmpty)
    }

    func testCodeOverTheSizeCapHasNoTokens() {
        let line = "x = 1\n"
        let underCap = String(repeating: line, count: 1_000)
        let overByteCap = String(repeating: "x = \"" + String(repeating: "a", count: 200) + "\"\n", count: 300)
        let overLineCap = String(repeating: line, count: 2_500)

        XCTAssertFalse(SyntaxHighlighter.tokens(in: underCap, language: "python").isEmpty)
        XCTAssertGreaterThan(overByteCap.utf8.count, 50 * 1024)
        XCTAssertTrue(SyntaxHighlighter.tokens(in: overByteCap, language: "python").isEmpty)
        XCTAssertTrue(SyntaxHighlighter.tokens(in: overLineCap, language: "python").isEmpty)
    }
}
