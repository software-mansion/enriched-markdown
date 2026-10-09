import SwiftUI
import UIKit
import XCTest
@testable import EnrichedMarkdown

@MainActor
final class TableThemingTests: XCTestCase {
    private let tableMarkdown = "| Name | Score | Notes |\n|:-----|:-----:|------:|\n"
        + "| alpha | ten | [docs](https://example.com) |\n| bravo | twelve | plain |"

    private func attachment(
        for markdown: String,
        config: MarkdownStyleConfiguration = .baseline(),
        options: MarkdownParsingOptions = .commonMark
    ) -> TableAttachment? {
        let rendered = MarkdownRenderer.render(markdown, config: config, options: options)
        var found: TableAttachment?
        rendered.enumerateAttribute(.attachment, in: NSRange(location: 0, length: rendered.length)) { value, _, _ in
            if let table = value as? TableAttachment { found = table }
        }
        return found
    }

    // MARK: - Theme element

    func testTableThemeElementAppliesToConfig() {
        var config = MarkdownStyleConfiguration()
        Table()
            .font(size: 15)
            .lineHeight(22)
            .foregroundStyle(Color(UIColor.systemRed))
            .headerForegroundStyle(Color(UIColor.systemBlue))
            .headerBackground(Color(UIColor.systemGreen))
            .rowEvenBackground(Color(UIColor.systemYellow))
            .rowOddBackground(Color(UIColor.systemOrange))
            .border(Color(UIColor.systemPurple), width: 2)
            .cornerRadius(9)
            .cellPadding(horizontal: 20, vertical: 10)
            .marginTop(4)
            .marginBottom(24)
            .alignment(.center)
            .apply(to: &config, traitCollection: .current)

        XCTAssertEqual(config.table.font?.pointSize, 15)
        XCTAssertEqual(config.table.lineHeight, 22)
        XCTAssertNotNil(config.table.foregroundColor)
        XCTAssertNotNil(config.table.headerTextColor)
        XCTAssertNotNil(config.table.headerBackgroundColor)
        XCTAssertNotNil(config.table.rowEvenBackgroundColor)
        XCTAssertNotNil(config.table.rowOddBackgroundColor)
        XCTAssertNotNil(config.table.borderColor)
        XCTAssertEqual(config.table.borderWidth, 2)
        XCTAssertEqual(config.table.cornerRadius, 9)
        XCTAssertEqual(config.table.cellPaddingHorizontal, 20)
        XCTAssertEqual(config.table.cellPaddingVertical, 10)
        XCTAssertEqual(config.table.marginTop, 4)
        XCTAssertEqual(config.table.marginBottom, 24)
        XCTAssertEqual(config.table.alignment, .center)
    }

    func testDefaultThemeTableColorsAdaptToDarkMode() {
        let light = MarkdownStyleConfiguration.resolve(
            layers: [.default],
            traitCollection: UITraitCollection(userInterfaceStyle: .light)
        )
        let dark = MarkdownStyleConfiguration.resolve(
            layers: [.default],
            traitCollection: UITraitCollection(userInterfaceStyle: .dark)
        )

        XCTAssertNotEqual(light.table.headerBackgroundColor, dark.table.headerBackgroundColor)
        XCTAssertNotEqual(light.table.borderColor, dark.table.borderColor)
        XCTAssertNotEqual(light.table.foregroundColor, dark.table.foregroundColor)
    }

    func testConfigDrivesAttachmentStyle() {
        var config = MarkdownStyleConfiguration.baseline()
        config.table.cellPaddingHorizontal = 20
        config.table.borderWidth = 3
        config.table.alignment = .trailing

        let table = attachment(for: tableMarkdown, config: config)

        XCTAssertEqual(table?.style.cellPaddingHorizontal, 20)
        XCTAssertEqual(table?.style.borderWidth, 3)
        XCTAssertEqual(table?.style.alignment, .trailing)
    }

    // MARK: - Cell styling

    func testCellAlignmentAndLineHeightApplied() {
        guard let table = attachment(for: tableMarkdown) else { return XCTFail("no table") }

        // Column 1 is center-aligned, column 2 right-aligned; every cell
        // carries the default 20pt line height.
        let centerCell = table.model.rows[1][1].attributedText
        let rightCell = table.model.rows[1][2].attributedText
        let centerStyle = centerCell.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        let rightStyle = rightCell.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle

        XCTAssertEqual(centerStyle?.alignment, .center)
        XCTAssertEqual(rightStyle?.alignment, .right)
        XCTAssertEqual(centerStyle?.minimumLineHeight, 20)
        XCTAssertEqual(centerStyle?.maximumLineHeight, 20)
    }

    // Cells are assembled separately from the document string, so the
    // baseline-shift pass has to run for them explicitly.
    func testSuperscriptAndSubscriptShiftInsideCells() {
        guard let table = attachment(
            for: "| A | B |\n|---|---|\n| x^2^ | H~2~O |",
            options: MarkdownParsingOptions(superscript: true, subscript: true)
        ) else { return XCTFail("no table") }

        let supCell = table.model.rows[1][0].attributedText
        let subCell = table.model.rows[1][1].attributedText
        XCTAssertEqual(supCell.string, "x2")
        XCTAssertEqual(subCell.string, "H2O")

        let baseSize = fontSize(in: supCell, at: 0)
        XCTAssertEqual(fontSize(in: supCell, at: 1), baseSize * 0.75, accuracy: 0.001)
        XCTAssertEqual(fontSize(in: subCell, at: 1), baseSize * 0.75, accuracy: 0.001)

        XCTAssertEqual(
            baselineOffset(in: supCell, at: 1) - baselineOffset(in: supCell, at: 0),
            baseSize * 0.35,
            accuracy: 0.001
        )
        XCTAssertEqual(
            baselineOffset(in: subCell, at: 1) - baselineOffset(in: subCell, at: 0),
            -baseSize * 0.20,
            accuracy: 0.001
        )
    }

    private func fontSize(in cell: NSAttributedString, at index: Int) -> CGFloat {
        (cell.attribute(.font, at: index, effectiveRange: nil) as? UIFont)?.pointSize ?? 0
    }

    private func baselineOffset(in cell: NSAttributedString, at index: Int) -> CGFloat {
        CGFloat((cell.attribute(.baselineOffset, at: index, effectiveRange: nil) as? NSNumber)?.doubleValue ?? 0)
    }

    func testHeaderFontFamilyOverridesHeaderCellsOnly() {
        var config = MarkdownStyleConfiguration.baseline()
        Table()
            .headerFont(custom: "Helvetica", size: 13)
            .apply(to: &config, traitCollection: .current)
        XCTAssertEqual(config.table.headerFont?.familyName, "Helvetica")
        XCTAssertEqual(config.table.headerFont?.pointSize, 13)

        guard let table = attachment(for: tableMarkdown, config: config) else {
            return XCTFail("no table")
        }
        let headerFont = table.model.rows[0][0].attributedText
            .attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        let bodyFont = table.model.rows[1][0].attributedText
            .attribute(.font, at: 0, effectiveRange: nil) as? UIFont

        XCTAssertEqual(headerFont?.familyName, "Helvetica")
        XCTAssertEqual(headerFont?.fontDescriptor.symbolicTraits.contains(.traitBold), true)
        XCTAssertNotEqual(bodyFont?.familyName, "Helvetica")
    }

    func testHeaderCellsUseBoldFont() {
        guard let table = attachment(for: tableMarkdown) else { return XCTFail("no table") }

        let headerFont = table.model.rows[0][0].attributedText
            .attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        let bodyFont = table.model.rows[1][0].attributedText
            .attribute(.font, at: 0, effectiveRange: nil) as? UIFont

        XCTAssertEqual(headerFont?.fontDescriptor.symbolicTraits.contains(.traitBold), true)
        XCTAssertEqual(bodyFont?.fontDescriptor.symbolicTraits.contains(.traitBold), false)
    }

    // MARK: - Copy

    func testPlainTextJoinsCellsWithTabsAndNewlines() {
        guard let table = attachment(for: tableMarkdown) else { return XCTFail("no table") }

        let plain = table.plainText()
        XCTAssertTrue(plain.contains("Name\tScore\tNotes"))
        XCTAssertTrue(plain.contains("bravo\ttwelve\tplain"))
        XCTAssertEqual(plain.components(separatedBy: "\n").count, 3)
    }

    func testMarkdownTextRebuildsPipeTableWithAlignments() {
        guard let table = attachment(for: tableMarkdown) else { return XCTFail("no table") }

        let markdown = table.markdownText()
        let lines = markdown.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 4)
        XCTAssertEqual(lines[0], "| Name | Score | Notes |")
        XCTAssertEqual(lines[1], "| :--- | :---: | ---: |")
        // Inline markdown inside cells is restored, not flattened.
        XCTAssertEqual(lines[2], "| alpha | ten | [docs](https://example.com) |")
    }

    func testMarkdownTextRestoresInlineFormatting() {
        guard let table = attachment(
            for: "| A | B |\n|---|---|\n| **bold** and `code` | *it* ~~gone~~ |"
        ) else { return XCTFail("no table") }

        let markdown = table.markdownText()
        XCTAssertTrue(markdown.contains("| **bold** and `code` | *it* ~~gone~~ |"))
    }

    func testCopyPlainTextReplacesTableCharacter() {
        let rendered = MarkdownRenderer.render(
            "before\n\n\(tableMarkdown)\n\nafter",
            config: .baseline()
        )
        let plain = MarkdownTextView.plainText(
            of: rendered,
            in: NSRange(location: 0, length: rendered.length)
        )

        XCTAssertFalse(plain.contains("\u{FFFC}"))
        XCTAssertTrue(plain.contains("Name\tScore\tNotes"))
        XCTAssertTrue(plain.contains("before"))
        XCTAssertTrue(plain.contains("after"))
    }

    // MARK: - Accessibility

    func testTableRowsBecomeAccessibilityElements() {
        let rendered = MarkdownRenderer.render(tableMarkdown, config: .baseline())
        let specs = MarkdownAccessibilityElementBuilder.specs(for: rendered)

        let rowSpecs = specs.filter {
            if case .tableRow = $0.kind { return true }
            return false
        }
        XCTAssertEqual(rowSpecs.count, 3)
        XCTAssertTrue(rowSpecs[0].label.hasPrefix("Row 1: Name, Score, Notes"))
        guard case .tableRow(let offset0, let height0, let isHeader0) = rowSpecs[0].kind,
              case .tableRow(let offset1, _, let isHeader1) = rowSpecs[1].kind else {
            return XCTFail("expected table row kinds")
        }
        XCTAssertTrue(isHeader0)
        XCTAssertFalse(isHeader1)
        XCTAssertEqual(offset0, 0)
        XCTAssertEqual(offset1, height0)
    }

    // MARK: - Link hit test

    func testLinkURLResolvesInsideLinkedCell() {
        guard let table = attachment(for: tableMarkdown) else { return XCTFail("no table") }
        let gridView = TableGridView(model: table.model, layout: table.layout, style: table.style)
        gridView.frame = CGRect(x: 0, y: 0, width: table.layout.totalWidth, height: table.layout.totalHeight)

        // The link sits in row 1 (first body row), column 2.
        let xOffset = table.layout.columnWidths[0] + table.layout.columnWidths[1]
        let yOffset = table.layout.rowHeights[0]
        let point = CGPoint(
            x: xOffset + table.style.cellPaddingHorizontal + 8,
            y: yOffset + table.style.cellPaddingVertical + 8
        )

        XCTAssertEqual(gridView.linkURL(at: point), URL(string: "https://example.com"))
        XCTAssertNil(gridView.linkURL(at: CGPoint(x: 5, y: 5)))
    }

    // MARK: - Align placement

    func testCenterAlignPositionsGridWhenTableFits() {
        var config = MarkdownStyleConfiguration.baseline()
        config.table.alignment = .center
        guard let table = attachment(for: "| A |\n|---|\n| x |", config: config) else {
            return XCTFail("no table")
        }

        let view = TableAttachmentView(attachment: table)
        view.frame = CGRect(x: 0, y: 0, width: 400, height: table.layout.totalHeight)
        view.layoutIfNeeded()

        guard let grid = view.firstSubview(of: TableGridView.self) else { return XCTFail("no grid view") }
        let expectedX = (400 - table.layout.totalWidth) / 2
        XCTAssertEqual(grid.frame.minX, expectedX, accuracy: 0.5)
    }

    func testScrollOffsetPersistsOnAttachment() {
        guard let table = attachment(
            for: "| A | B | C | D | E | F | G |\n|---|---|---|---|---|---|---|\n| one | two | three | four | five | six | seven |"
        ) else { return XCTFail("no table") }
        XCTAssertGreaterThan(table.layout.totalWidth, 300)

        let view = TableAttachmentView(attachment: table)
        view.frame = CGRect(x: 0, y: 0, width: 300, height: table.layout.totalHeight)
        view.layoutIfNeeded()

        guard let scrollView = view.subviews.compactMap({ $0 as? UIScrollView }).first else {
            return XCTFail("no scroll view")
        }
        scrollView.contentOffset = CGPoint(x: 42, y: 0)
        XCTAssertEqual(table.preservedContentOffset.x, 42)

        // A recreated view (viewport re-entry) restores the offset.
        let recreated = TableAttachmentView(attachment: table)
        recreated.frame = CGRect(x: 0, y: 0, width: 300, height: table.layout.totalHeight)
        recreated.layoutIfNeeded()
        let recreatedScroll = recreated.subviews.compactMap { $0 as? UIScrollView }.first
        XCTAssertEqual(recreatedScroll?.contentOffset.x, 42)
    }

    // MARK: - alignment(_:)

    func testAlignmentTakesSwiftUIHorizontalAlignment() {
        let config = MarkdownStyleConfiguration.resolve(
            layers: [MarkdownTheme { Table().alignment(.trailing) }],
            traitCollection: .current
        )
        XCTAssertEqual(config.table.alignment, .trailing)
    }

    func testUnsupportedHorizontalAlignmentLeavesInheritedValue() {
        let config = MarkdownStyleConfiguration.resolve(
            layers: [
                MarkdownTheme { Table().alignment(.center) },
                MarkdownTheme { Table().alignment(.listRowSeparatorLeading) }
            ],
            traitCollection: .current
        )
        XCTAssertEqual(config.table.alignment, .center)
    }

    // MARK: - Grouped modifiers

    func testBorderWithoutWidthKeepsTheLowerLayersWidth() {
        let config = MarkdownStyleConfiguration.resolve(
            layers: [
                MarkdownTheme { Table().border(Color(UIColor.systemBlue), width: 4) },
                MarkdownTheme { Table().border(Color(UIColor.systemRed)) }
            ],
            traitCollection: .current
        )
        XCTAssertEqual(config.table.borderColor, UIColor.systemRed.resolvedColor(with: .current))
        XCTAssertEqual(config.table.borderWidth, 4)
    }

    func testBorderWidthAloneKeepsTheLowerLayersColor() {
        let config = MarkdownStyleConfiguration.resolve(
            layers: [
                MarkdownTheme { Table().border(Color(UIColor.systemBlue), width: 1) },
                MarkdownTheme { Table().border(width: 5) }
            ],
            traitCollection: .current
        )
        XCTAssertEqual(config.table.borderColor, UIColor.systemBlue.resolvedColor(with: .current))
        XCTAssertEqual(config.table.borderWidth, 5)
    }

    func testCellPaddingSetsOnlyTheGivenSides() {
        let config = MarkdownStyleConfiguration.resolve(
            layers: [
                MarkdownTheme { Table().cellPadding(horizontal: 12, vertical: 8) },
                MarkdownTheme { Table().cellPadding(vertical: 2) }
            ],
            traitCollection: .current
        )
        XCTAssertEqual(config.table.cellPaddingHorizontal, 12)
        XCTAssertEqual(config.table.cellPaddingVertical, 2)
    }

    // MARK: - Header font and color

    func testHeaderFontTakesATextStyleWithWeight() throws {
        let config = MarkdownStyleConfiguration.resolve(
            layers: [.default, MarkdownTheme { Table().headerFont(.system(.caption, weight: .bold)).headerForegroundStyle(.tertiary) }],
            traitCollection: .current
        )
        let font = try XCTUnwrap(config.table.headerFont)
        XCTAssertEqual(font.pointSize, UIFont.preferredFont(forTextStyle: .caption1).pointSize)
        XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitBold))
        XCTAssertEqual(config.table.headerTextColor, UIColor.tertiaryLabel.resolvedColor(with: .current))
    }
}
