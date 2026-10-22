import UIKit
import XCTest
@testable import EnrichedMarkdown

final class HTMLLineBreakTests: XCTestCase {
    func testParagraphEmitsExistingLineBreakNodes() {
        for tag in ["<br>", "<br/>", "<br />", "<BR>", "<Br/>", "<bR />"] {
            let ast = Parser.shared.parseMarkdown("one\(tag)two")
            let paragraph = ast.child(ofType: .paragraph)
            XCTAssertEqual(paragraph?.children.map(\.type), [.text, .lineBreak, .text], tag)
            XCTAssertEqual(paragraph?.children.first?.content, "one", tag)
            XCTAssertEqual(paragraph?.children.last?.content, "two", tag)
            let rendered = MarkdownRenderer.render("one\(tag)two", config: .baseline())
            XCTAssertEqual(rendered.string.trimmingCharacters(in: .newlines), "one\u{2028}two", tag)
        }
    }

    @MainActor
    func testTableBreaksStayInsideTheCell() throws {
        let source = "| Head<br>two | Code |\n| --- | --- |\n| one<br/>two<BR />three | `one<br>two` |"
        let ast = Parser.shared.parseMarkdown(source)
        XCTAssertEqual(ast.all(ofType: .lineBreak).count, 3)
        XCTAssertEqual(ast.all(ofType: .tableRow).count, 2)
        let rendered = MarkdownRenderer.render(source, config: .baseline())
        var table: TableAttachment?
        rendered.enumerateAttribute(.attachment, in: NSRange(location: 0, length: rendered.length)) { value, _, _ in
            if let value = value as? TableAttachment { table = value }
        }
        let attachment = try XCTUnwrap(table)
        XCTAssertEqual(attachment.model.rows[0][0].attributedText.string, "Head\u{2028}two")
        XCTAssertEqual(attachment.model.rows[1][0].attributedText.string, "one\u{2028}two\u{2028}three")
        XCTAssertEqual(attachment.model.rows[1][1].attributedText.string, "one<br>two")
    }

    func testLiteralControlsAndAutolinks() {
        let controls = [
            "\\<br>", "&lt;br&gt;", "`one<br>two`", "```html\none<br>two\n```",
            "one<br class=\"x\">two", "one<br title=\"<br>\">two", "text <!-- <br> -->",
            "one<br >two", "one<br  />two", "one<br/ >two", "one</br>two"
        ]
        for source in controls {
            XCTAssertTrue(Parser.shared.parseMarkdown(source).all(ofType: .lineBreak).isEmpty, source)
        }
        XCTAssertEqual(Parser.shared.parseMarkdown("<br@example.org>").all(ofType: .link).count, 1)
        XCTAssertEqual(Parser.shared.parseMarkdown("<https://example.org>").all(ofType: .link).count, 1)
    }
}
