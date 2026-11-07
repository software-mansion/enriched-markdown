import UIKit
import XCTest
@testable import EnrichedMarkdown

final class AttributedTextDiffTests: XCTestCase {
    func testAppendIsAnInsertion() {
        let old = NSAttributedString(string: "Hello wor\n")
        let new = NSAttributedString(string: "Hello world\n")
        let diff = AttributedTextDiff(from: old, to: new)
        XCTAssertEqual(diff.replacedRange, NSRange(location: 9, length: 0))
        XCTAssertEqual(diff.replacementRange, NSRange(location: 9, length: 2))
        XCTAssertEqual(diff.insertedRange, NSRange(location: 9, length: 2))
    }

    func testRestyledTextIsReplacedButNotInserted() {
        let old = NSAttributedString(string: "plain text")
        let new = NSMutableAttributedString(string: "plain text")
        new.addAttribute(.foregroundColor, value: UIColor.red, range: NSRange(location: 6, length: 4))
        let diff = AttributedTextDiff(from: old, to: new)
        XCTAssertEqual(diff.replacedRange, NSRange(location: 6, length: 4))
        XCTAssertEqual(diff.insertedRange.length, 0)
    }

    func testEqualTextIsEmpty() {
        let text = NSAttributedString(string: "same", attributes: [.font: UIFont.systemFont(ofSize: 14)])
        XCTAssertTrue(AttributedTextDiff(from: text, to: NSAttributedString(attributedString: text)).isEmpty)
    }

    func testRerenderedAttachmentsCompareByContent() {
        let config = MarkdownStyleConfiguration.baseline()
        let markdown = "| A | B |\n|---|---|\n| 1 | 2 |"
        let first = MarkdownRenderer.render(markdown, config: config)
        let second = MarkdownRenderer.render(markdown, config: config)
        XCTAssertTrue(AttributedTextDiff.isEquivalent(first, second))
        let changed = MarkdownRenderer.render(markdown + "\n| 3 | 4 |", config: config)
        XCTAssertFalse(AttributedTextDiff.isEquivalent(first, changed))
    }

    func testPendingCodeBlockDiffersFromItsClosedForm() {
        let style = CodeBlockAttachmentStyle(config: .baseline())
        let code = CodeBlockAttachment.attributedCode("let x = 1", style: style)
        func text(isPending: Bool) -> NSAttributedString {
            NSAttributedString(string: "\u{FFFC}", attributes: [
                .attachment: CodeBlockAttachment(
                    code: "let x = 1",
                    language: "swift",
                    fenceCharacter: "`",
                    attributedCode: code,
                    style: style,
                    isPending: isPending
                )
            ])
        }
        XCTAssertFalse(AttributedTextDiff.isEquivalent(text(isPending: true), text(isPending: false)))
        XCTAssertTrue(AttributedTextDiff.isEquivalent(text(isPending: false), text(isPending: false)))
    }
}
