import UIKit
import XCTest
@testable import EnrichedMarkdown

@MainActor
final class TableAttachmentTests: XCTestCase {
    private var config: MarkdownStyleConfig!

    override func setUp() {
        super.setUp()
        config = MarkdownStyleConfig.baseline()
    }

    func testTableRendersAsSingleAttachment() {
        let rendered = MarkdownRenderer.render(
            "before\n\n| A | B |\n|---|---|\n| one | two |\n\nafter",
            config: config
        )

        var attachments: [TableAttachment] = []
        rendered.enumerateAttribute(.attachment, in: NSRange(location: 0, length: rendered.length)) { value, _, _ in
            if let table = value as? TableAttachment { attachments.append(table) }
        }

        XCTAssertEqual(attachments.count, 1)
        let attachment = attachments[0]
        XCTAssertEqual(attachment.model.columnCount, 2)
        XCTAssertEqual(attachment.model.rows.count, 2)
        XCTAssertTrue(attachment.model.rows[0].allSatisfy(\.isHeader))
        XCTAssertFalse(attachment.model.rows[1].contains { $0.isHeader })
        XCTAssertTrue(rendered.string.contains("before"))
        XCTAssertTrue(rendered.string.contains("after"))
    }

    func testColumnWidthsAreClampedAndHeightsAccumulate() {
        let longText = String(repeating: "wide content ", count: 30)
        let rendered = MarkdownRenderer.render(
            "| A | B |\n|---|---|\n| x | \(longText) |",
            config: config
        )
        var attachment: TableAttachment?
        rendered.enumerateAttribute(.attachment, in: NSRange(location: 0, length: rendered.length)) { value, _, _ in
            if let table = value as? TableAttachment { attachment = table }
        }
        guard let attachment else { return XCTFail("no table attachment") }

        let horizontalPadding = attachment.style.cellPaddingHorizontal * 2
        // The long column wraps near the 300pt cap: its width lands at the
        // last word boundary at or under the cap.
        XCTAssertEqual(attachment.layout.columnWidths[0], TableAttachmentStyle.minColumnWidth)
        XCTAssertLessThanOrEqual(
            attachment.layout.columnWidths[1],
            TableAttachmentStyle.maxColumnWidth + horizontalPadding
        )
        XCTAssertGreaterThan(attachment.layout.columnWidths[1], TableAttachmentStyle.maxColumnWidth * 0.8)
        XCTAssertEqual(attachment.layout.rowHeights.count, 2)
        XCTAssertGreaterThan(attachment.layout.rowHeights[1], attachment.layout.rowHeights[0])
        XCTAssertEqual(
            attachment.layout.totalHeight,
            attachment.layout.rowHeights.reduce(0, +) + attachment.style.borderWidth
        )
    }

    /// Breaks silently with an undeclared UTI, nil contents, or an
    /// attachment-side viewProvider override.
    func testProviderViewIsInstalledInTextView() {
        let rendered = MarkdownRenderer.render(
            "before\n\n| A | B |\n|---|---|\n| one | two |\n\nafter",
            config: config
        )

        let textView = MarkdownTextView()
        textView.styleConfig = config
        textView.frame = CGRect(x: 0, y: 0, width: 380, height: 10)
        textView.setMarkdownAttributedText(rendered)

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 380, height: 1000))
        window.addSubview(textView)
        window.makeKeyAndVisible()
        let fitted = textView.sizeThatFits(CGSize(width: 380, height: CGFloat.greatestFiniteMagnitude))
        textView.frame.size.height = fitted.height
        textView.layoutIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
        textView.layoutIfNeeded()

        XCTAssertNotNil(findTableView(in: textView))
        window.isHidden = true
    }

    private func findTableView(in view: UIView) -> TableAttachmentView? {
        if let table = view as? TableAttachmentView { return table }
        for subview in view.subviews {
            if let found = findTableView(in: subview) { return found }
        }
        return nil
    }
}
