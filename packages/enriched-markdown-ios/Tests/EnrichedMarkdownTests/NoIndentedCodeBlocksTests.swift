import EnrichedMarkdown
import XCTest

final class NoIndentedCodeBlocksTests: XCTestCase {
    func testDefaultAndOptInPreserveFencedCode() {
        let markdown = "    **spaces**\n\nSeparator.\n\n\t*tab*\n\n```js\nfenced\n```\n\n~~~\ntilde\n~~~"
        let parser = Parser.shared
        XCTAssertEqual(parser.parseMarkdown(markdown).children.filter { $0.type == .codeBlock }.count, 4)
        for enabled in [false, true, false] {
            let ast = parser.parseMarkdown(markdown, options: MarkdownParsingOptions(noIndentedCodeBlocks: enabled))
            XCTAssertEqual(ast.children.filter { $0.type == .codeBlock }.count, enabled ? 2 : 4)
            XCTAssertEqual(ast.first(ofType: .strong) != nil, enabled)
            XCTAssertEqual(ast.first(ofType: .emphasis) != nil, enabled)
        }
    }
}
