import UIKit
import XCTest
@testable import EnrichedMarkdown

final class ParagraphStyleHelpersTests: XCTestCase {
    func testEnsureTrailingNewlineAppendsWhenMissing() {
        let output = NSMutableAttributedString(string: "text")
        ParagraphStyleHelpers.ensureTrailingNewline(in: output)
        XCTAssertTrue(output.string.hasSuffix("\n"))
    }

    func testEnsureTrailingNewlineDoesNotDuplicate() {
        let output = NSMutableAttributedString(string: "text\n")
        ParagraphStyleHelpers.ensureTrailingNewline(in: output)
        XCTAssertEqual(output.string, "text\n")
    }

    func testApplyBlockSpacingAfterAppendsSpacerNewline() {
        let output = NSMutableAttributedString(string: "block")
        ParagraphStyleHelpers.applyBlockSpacingAfter(to: output, marginBottom: 16)

        XCTAssertEqual(output.string, "block\n")
        let style = output.attribute(.paragraphStyle, at: output.length - 1, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(style?.paragraphSpacing, 16)
    }

    func testApplyParagraphSpacingAfterSetsParagraphSpacingOnContent() {
        let output = NSMutableAttributedString(string: "Hello")
        ParagraphStyleHelpers.applyParagraphSpacingAfter(to: output, at: 0, marginBottom: 16)

        XCTAssertEqual(output.string, "Hello\n")
        let contentStyle = output.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(contentStyle?.paragraphSpacing, 16)
    }

    func testApplyParagraphSpacingAfterWithZeroMarginAppendsNewline() {
        let output = NSMutableAttributedString(string: "Hello")
        ParagraphStyleHelpers.applyParagraphSpacingAfter(to: output, at: 0, marginBottom: 0)

        XCTAssertEqual(output.string, "Hello\n")
        let contentStyle = output.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(contentStyle?.paragraphSpacing, 0)
    }

    func testApplyBlockLineHeightSetsParagraphStyleAndBaselineOffset() {
        let font = UIFont.systemFont(ofSize: 16, weight: .regular)
        let output = NSMutableAttributedString(
            string: "Hello",
            attributes: [.font: font]
        )

        ParagraphStyleHelpers.applyBlockLineHeight(
            to: output,
            range: NSRange(location: 0, length: output.length),
            lineHeight: 26
        )

        let style = output.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(style?.minimumLineHeight, 26)
        XCTAssertEqual(style?.maximumLineHeight, 26)

        let baselineOffset = output.attribute(.baselineOffset, at: 0, effectiveRange: nil) as? CGFloat
        XCTAssertNotNil(baselineOffset)
        XCTAssertGreaterThan(baselineOffset ?? 0, 0)
    }
}
