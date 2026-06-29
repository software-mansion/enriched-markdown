import EnrichedMarkdown
import XCTest

final class ParserTests: XCTestCase {
    private let parser = Parser.shared

    func testBlankInputReturnsEmptyDocument() {
        let empty = parser.parseMarkdown("")
        XCTAssertEqual(empty.type, .document)
        XCTAssertTrue(empty.children.isEmpty)

        let whitespace = parser.parseMarkdown("   ")
        XCTAssertEqual(whitespace.type, .document)
        XCTAssertTrue(whitespace.children.isEmpty)
    }

    func testParsesPlainParagraph() {
        let ast = parser.parseMarkdown("Hello world")

        XCTAssertEqual(ast.type, .document)
        let paragraph = ast.child(ofType: .paragraph)
        XCTAssertNotNil(paragraph)
        let text = paragraph?.child(ofType: .text)
        XCTAssertEqual(text?.content, "Hello world")
    }

    func testParsesStrongAndEmphasis() {
        let ast = parser.parseMarkdown("**bold** and *italic*")

        let strong = ast.first(ofType: .strong)
        XCTAssertNotNil(strong)
        XCTAssertEqual(strong?.child(ofType: .text)?.content, "bold")

        let emphasis = ast.first(ofType: .emphasis)
        XCTAssertNotNil(emphasis)
        XCTAssertEqual(emphasis?.child(ofType: .text)?.content, "italic")
    }

    func testParsesBoldItalicNesting() {
        let ast = parser.parseMarkdown("***both***")

        let strong = ast.first(ofType: .strong)
        let emphasis = ast.first(ofType: .emphasis)
        XCTAssertNotNil(strong)
        XCTAssertNotNil(emphasis)

        if strong?.first(ofType: .emphasis) != nil {
            XCTFail("md4c nests as strong > emphasis")
        } else {
            XCTAssertNotNil(emphasis?.first(ofType: .strong), "expected emphasis > strong")
            XCTAssertEqual(emphasis?.child(ofType: .strong)?.child(ofType: .text)?.content, "both")
        }
    }

    func testParsesLinkWithHref() {
        let ast = parser.parseMarkdown("[React Native](https://reactnative.dev)")

        let link = ast.first(ofType: .link)
        XCTAssertNotNil(link)
        XCTAssertEqual(link?.child(ofType: .text)?.content, "React Native")
        XCTAssertEqual(link?.attribute("url"), "https://reactnative.dev")
    }

    func testParsesHeadingWithLevel() {
        let ast = parser.parseMarkdown("## Section")

        let heading = ast.first(ofType: .heading)
        XCTAssertNotNil(heading)
        XCTAssertEqual(heading?.attribute("level"), "2")
        XCTAssertEqual(heading?.child(ofType: .text)?.content, "Section")
    }

    func testParsesNestedList() {
        let markdown = """
        1. first
        2. second
        """

        let ast = parser.parseMarkdown(markdown)

        let orderedList = ast.first(ofType: .orderedList)
        XCTAssertNotNil(orderedList)

        let listItems = orderedList?.all(ofType: .listItem) ?? []
        XCTAssertEqual(listItems.count, 2)
        XCTAssertTrue(listItems[0].first(ofType: .text)?.content.contains("first") == true)
        XCTAssertTrue(listItems[1].first(ofType: .text)?.content.contains("second") == true)
    }

    func testParsesCodeBlock() {
        let ast = parser.parseMarkdown("```\nval x = 1\n```")

        let codeBlock = ast.first(ofType: .codeBlock)
        XCTAssertNotNil(codeBlock)

        let codeText = codeBlock?.first(ofType: .text)
        XCTAssertTrue(codeText?.content.contains("val x = 1") == true)
    }

    func testParsesUnicodeContent() {
        let ast = parser.parseMarkdown("Cześć 🌍")

        let text = ast.first(ofType: .text)
        XCTAssertEqual(text?.content, "Cześć 🌍")
    }

    func testNodeTypeEnumCountMatches() {
        XCTAssertEqual(NodeType.allCases.count, 30)
    }

    func testParsesDeeplyNestedBlockquotes() {
        let depth = 500
        let markdown = String(repeating: "> ", count: depth) + "deep"

        let ast = parser.parseMarkdown(markdown)

        let text = ast.first(ofType: .text)
        XCTAssertEqual(text?.content, "deep")
        XCTAssertEqual(ast.all(ofType: .blockquote).count, depth)
    }

    func testParsesWideUnorderedList() {
        let itemCount = 600
        let markdown = (1...itemCount).map { "- item \($0)" }.joined(separator: "\n")

        let ast = parser.parseMarkdown(markdown)

        let list = ast.first(ofType: .unorderedList)
        XCTAssertNotNil(list)

        let listItems = list?.children.filter { $0.type == .listItem } ?? []
        XCTAssertEqual(listItems.count, itemCount)
        XCTAssertEqual(
            listItems.first?.first(ofType: .text)?.content.trimmingCharacters(in: .whitespacesAndNewlines),
            "item 1"
        )
        XCTAssertEqual(
            listItems.last?.first(ofType: .text)?.content.trimmingCharacters(in: .whitespacesAndNewlines),
            "item \(itemCount)"
        )
    }
}
