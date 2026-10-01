import SwiftUI
import UIKit
import XCTest
@testable import EnrichedMarkdown

/// Every 0.1 name kept as a deprecated shim forwards to its replacement.
/// Delete this file with the shims.
@available(*, deprecated)
final class DeprecatedAPITests: XCTestCase {
    private func resolve(@MarkdownThemeBuilder _ content: () -> MarkdownThemeGroup) -> MarkdownStyleConfiguration {
        MarkdownStyleConfiguration.resolve(layers: [MarkdownTheme(content)], traitCollection: .current)
    }

    func testParsingOptionsTypealiasAndLabels() {
        let flags: Md4cFlags = Md4cFlags(underline: true)
        XCTAssertEqual(flags, MarkdownParsingOptions(underline: true))
        _ = EnrichedMarkdownText("x", flags: flags)
        let node = Parser.shared.parseMarkdown("__u__", flags: flags)
        XCTAssertNotNil(node)
        let rendered = MarkdownRenderer.render("**b**", config: .baseline(), flags: flags)
        XCTAssertEqual(rendered.string.trimmingCharacters(in: .whitespacesAndNewlines), "b")
    }

    func testElementModifierShimsForwardToNewNames() {
        let config = resolve {
            BlockImage().borderRadius(7)
            CodeBlock().borderRadius(5).textAlignment(.center)
            Table().borderRadius(3).align(.trailing)
            TaskList().checkboxBorderRadius(2)
            List().marginLeft(30)
            ThematicBreak().color(Color(UIColor.systemRed))
            Spoiler().color(.secondary)
        }
        XCTAssertEqual(config.image.cornerRadius, 7)
        XCTAssertEqual(config.codeBlock.cornerRadius, 5)
        XCTAssertEqual(config.codeBlock.textAlignment, NSTextAlignment.center)
        XCTAssertEqual(config.table.cornerRadius, 3)
        XCTAssertEqual(config.table.alignment, TableAlignment.trailing)
        XCTAssertEqual(config.taskList.checkboxCornerRadius, 2)
        XCTAssertEqual(config.list.marginLeading, 30)
        XCTAssertEqual(config.thematicBreak.color, UIColor.systemRed.resolvedColor(with: .current))
        XCTAssertNotNil(config.spoiler.color)
    }

    func testGroupedModifierShimsForwardToGroupedForms() {
        let config = resolve {
            CodeBlock().borderColor(Color(UIColor.systemRed)).borderWidth(2)
            Table().cellPaddingHorizontal(11).cellPaddingVertical(7)
            Spoiler().particleDensity(3).particleSpeed(4).solidBorderRadius(5)
        }
        XCTAssertEqual(config.codeBlock.borderColor, UIColor.systemRed.resolvedColor(with: .current))
        XCTAssertEqual(config.codeBlock.borderWidth, 2)
        XCTAssertEqual(config.table.cellPaddingHorizontal, 11)
        XCTAssertEqual(config.table.cellPaddingVertical, 7)
        XCTAssertEqual(config.spoiler.particleDensity, 3)
        XCTAssertEqual(config.spoiler.particleSpeed, 4)
        XCTAssertEqual(config.spoiler.solidCornerRadius, 5)
        XCTAssertEqual(SpoilerStyle(solidBorderRadius: 8).solidCornerRadius, 8)
    }

    func testFontAndHeaderShimsForwardToNewNames() {
        let config = resolve {
            Heading(1).fontSize(30, weight: .semibold)
            Heading(2).fontFamily("Helvetica", size: 24)
            Table().headerFontFamily("Helvetica", size: 13).headerTextColor(Color(UIColor.systemRed))
        }
        XCTAssertEqual(config.heading1.font?.pointSize, 30)
        XCTAssertEqual(config.heading2.font?.familyName, "Helvetica")
        XCTAssertEqual(config.table.headerFont?.pointSize, 13)
        XCTAssertEqual(config.table.headerTextColor, UIColor.systemRed.resolvedColor(with: .current))
        let legacy: MarkdownStyleConfig = MarkdownStyleConfiguration.baseline()
        let rendered = MarkdownRenderer.render("x", config: legacy, flags: .commonMark)
        XCTAssertEqual(rendered.string.trimmingCharacters(in: .whitespacesAndNewlines), "x")
    }

    func testStyleRecordFieldAliasesAndInitLabels() {
        var codeBlock = CodeBlockStyle(borderRadius: 4)
        XCTAssertEqual(codeBlock.cornerRadius, 4)
        codeBlock.borderRadius = 6
        XCTAssertEqual(codeBlock.cornerRadius, 6)

        XCTAssertEqual(ImageStyle(borderRadius: 1).cornerRadius, 1)
        XCTAssertEqual(TaskListStyle(checkboxBorderRadius: 2).checkboxCornerRadius, 2)
        XCTAssertEqual(ListStyle(marginLeft: 3).marginLeading, 3)

        let both = TableStyle(borderRadius: 4, align: .center)
        XCTAssertEqual(both.cornerRadius, 4)
        XCTAssertEqual(both.alignment, .center)
        XCTAssertEqual(TableStyle(borderRadius: 5).cornerRadius, 5)
        XCTAssertEqual(TableStyle(align: .leading).alignment, .leading)
        XCTAssertEqual(TableStyle().align, nil)
    }

    func testTaskListAndSelectionMenuShims() {
        let event = TaskListItemPressEvent(index: 1, checked: true, text: "t")
        XCTAssertEqual(event, TaskListItemToggle(index: 1, isChecked: true, text: "t"))
        XCTAssertTrue(event.checked)

        var environment = EnvironmentValues()
        environment.markdownTaskListItemPressHandler = { _ in }
        XCTAssertNotNil(environment.markdownTaskListItemToggleHandler)

        var menu: MarkdownSelectionMenuConfig = MarkdownSelectionMenuConfig(copyImageUrl: false)
        XCTAssertFalse(menu.copyImageURL)
        menu.copyImageUrl = true
        XCTAssertTrue(menu.copyImageURL)
    }

    func testViewModifierShimsCompile() {
        _ = EnrichedMarkdownText("x")
            .onLinkPress { _ in }
            .onLinkLongPress { _ in }
            .onTaskListItemPress { _ in }
            .markdownSelectable(false)
    }

    @MainActor
    func testRememberMarkdownThemeStillBuildsATheme() {
        let theme = rememberMarkdownTheme(colorScheme: .dark, dynamicTypeSize: .large) {
            Paragraph().lineHeight(33)
        }
        let config = MarkdownStyleConfiguration.resolve(layers: [theme], traitCollection: .current)
        XCTAssertEqual(config.paragraph.lineHeight, 33)
    }
}
