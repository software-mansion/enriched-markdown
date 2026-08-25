import SwiftUI
import UIKit
import XCTest
@testable import EnrichedMarkdown

final class TaskListRenderingTests: XCTestCase {
    private var config: MarkdownStyleConfig!

    override func setUp() {
        super.setUp()
        config = MarkdownStyleConfig.baseline()
    }

    // MARK: - Parsing

    func testParserEmitsTaskAttributesOnListItems() {
        let ast = Parser.shared.parseMarkdown("- [x] done\n- [ ] todo")

        let items = ast.all(ofType: .listItem)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].attribute("isTask"), "true")
        XCTAssertEqual(items[0].attribute("taskChecked"), "true")
        XCTAssertEqual(items[1].attribute("isTask"), "true")
        XCTAssertEqual(items[1].attribute("taskChecked"), "false")
    }

    func testParserLeavesRegularItemsUnmarked() {
        let ast = Parser.shared.parseMarkdown("- plain item")

        let item = ast.first(ofType: .listItem)
        XCTAssertNil(item?.attribute("isTask"))
    }

    // MARK: - Rendered attributes

    func testTaskItemsCarryCheckedStateAttribute() {
        let result = MarkdownRenderer.render("- [x] done\n- [ ] todo", config: config)
        let string = result.string as NSString

        let doneLocation = string.range(of: "done").location
        let todoLocation = string.range(of: "todo").location
        XCTAssertTrue(MarkdownAttributeValue.boolValue(
            from: result.attribute(MarkdownAttribute.taskListItem, at: doneLocation, effectiveRange: nil)
        ))
        let todoValue = result.attribute(MarkdownAttribute.taskListItem, at: todoLocation, effectiveRange: nil)
        XCTAssertNotNil(todoValue)
        XCTAssertFalse(MarkdownAttributeValue.boolValue(from: todoValue))
    }

    func testRegularItemsHaveNoTaskAttribute() {
        let result = MarkdownRenderer.render("- plain item", config: config)
        let location = (result.string as NSString).range(of: "plain").location

        XCTAssertNil(result.attribute(MarkdownAttribute.taskListItem, at: location, effectiveRange: nil))
    }

    // MARK: - Indent

    func testTaskItemIndentReservesCheckboxWidth() {
        let result = MarkdownRenderer.render("- [ ] task\n- bullet", config: config)
        let string = result.string as NSString

        let taskStyle = result.attribute(
            .paragraphStyle,
            at: string.range(of: "task").location,
            effectiveRange: nil
        ) as? NSParagraphStyle
        let bulletStyle = result.attribute(
            .paragraphStyle,
            at: string.range(of: "bullet").location,
            effectiveRange: nil
        ) as? NSParagraphStyle

        // Default theme: checkboxSize 14 + gap 12 vs bulletSize 6 + gap 12.
        XCTAssertEqual(taskStyle?.headIndent, 26)
        XCTAssertEqual(bulletStyle?.headIndent, 18)
    }

    func testOrderedTaskItemsAlignWithSiblingNumbers() {
        let result = MarkdownRenderer.render("1. [x] done step\n2. plain step", config: config)

        // The checkbox column widens to the ordered marker column, so task
        // and plain items in the same ordered list share one text indent.
        XCTAssertEqual(paragraphStyle(in: result, at: "done")?.headIndent, 32)
        XCTAssertEqual(paragraphStyle(in: result, at: "plain")?.headIndent, 32)
    }

    func testListItemsInsideBlockquoteKeepMarkerColumn() {
        let result = MarkdownRenderer.render("> intro\n> - [ ] quoted task\n> - plain quoted", config: config)

        // Default theme quote offset: borderWidth 3 + gapWidth 16 = 19.
        XCTAssertEqual(paragraphStyle(in: result, at: "intro")?.headIndent, 19)
        XCTAssertEqual(paragraphStyle(in: result, at: "quoted task")?.headIndent, 19 + 26)
        XCTAssertEqual(paragraphStyle(in: result, at: "plain quoted")?.headIndent, 19 + 18)

        // The quote border/background must still span the list items.
        let string = result.string as NSString
        let taskLocation = string.range(of: "quoted task").location
        XCTAssertNotNil(result.attribute(MarkdownAttribute.blockquoteDepth, at: taskLocation, effectiveRange: nil))
        XCTAssertNotNil(result.attribute(MarkdownAttribute.taskListItem, at: taskLocation, effectiveRange: nil))
    }

    private func paragraphStyle(in result: NSAttributedString, at substring: String) -> NSParagraphStyle? {
        let range = (result.string as NSString).range(of: substring)
        guard range.location != NSNotFound else { return nil }
        return result.attribute(.paragraphStyle, at: range.location, effectiveRange: nil) as? NSParagraphStyle
    }

    // MARK: - Checked decoration

    func testCheckedItemAppliesTextColorAndStrikethrough() {
        config.taskList.checkedTextColor = .red
        config.taskList.checkedStrikethrough = true
        let result = MarkdownRenderer.render("- [x] done\n- [ ] todo", config: config)
        let string = result.string as NSString

        let doneLocation = string.range(of: "done").location
        XCTAssertEqual(
            result.attribute(.foregroundColor, at: doneLocation, effectiveRange: nil) as? UIColor,
            .red
        )
        XCTAssertEqual(
            MarkdownAttributeValue.intValue(
                from: result.attribute(.strikethroughStyle, at: doneLocation, effectiveRange: nil)
            ),
            NSUnderlineStyle.single.rawValue
        )
        XCTAssertEqual(
            result.attribute(.strikethroughColor, at: doneLocation, effectiveRange: nil) as? UIColor,
            .red
        )

        let todoLocation = string.range(of: "todo").location
        XCTAssertNotEqual(
            result.attribute(.foregroundColor, at: todoLocation, effectiveRange: nil) as? UIColor,
            .red
        )
        XCTAssertNil(result.attribute(.strikethroughStyle, at: todoLocation, effectiveRange: nil))
    }

    func testUncheckedItemGetsNoDecorationWithoutConfig() {
        let result = MarkdownRenderer.render("- [x] done", config: config)
        let location = (result.string as NSString).range(of: "done").location

        XCTAssertNil(result.attribute(.strikethroughStyle, at: location, effectiveRange: nil))
    }

    func testCheckedDecorationSkipsNestedItems() {
        config.taskList.checkedTextColor = .red
        let result = MarkdownRenderer.render("- [x] parent\n  - child", config: config)
        let string = result.string as NSString

        XCTAssertEqual(
            result.attribute(
                .foregroundColor,
                at: string.range(of: "parent").location,
                effectiveRange: nil
            ) as? UIColor,
            .red
        )
        XCTAssertNotEqual(
            result.attribute(
                .foregroundColor,
                at: string.range(of: "child").location,
                effectiveRange: nil
            ) as? UIColor,
            .red
        )
    }

    func testCheckedDecorationPreservesLinkColor() {
        config.taskList.checkedTextColor = .red
        let linkColor = config.link.foregroundColor
        let result = MarkdownRenderer.render("- [x] see [docs](https://example.com)", config: config)
        let location = (result.string as NSString).range(of: "docs").location

        XCTAssertEqual(
            result.attribute(.foregroundColor, at: location, effectiveRange: nil) as? UIColor,
            linkColor
        )
    }

    // MARK: - Theme element

    func testTaskListThemeElementAppliesToConfig() {
        var applied = MarkdownStyleConfig()
        TaskList()
            .checkedColor(Color(UIColor.systemGreen))
            .borderColor(Color(UIColor.systemGray))
            .checkmarkColor(Color(UIColor.black))
            .checkedTextColor(Color(UIColor.systemGray2))
            .checkboxSize(20)
            .checkboxBorderRadius(5)
            .checkedStrikethrough()
            .apply(to: &applied, traitCollection: .current)

        XCTAssertNotNil(applied.taskList.checkedColor)
        XCTAssertNotNil(applied.taskList.borderColor)
        XCTAssertNotNil(applied.taskList.checkmarkColor)
        XCTAssertNotNil(applied.taskList.checkedTextColor)
        XCTAssertEqual(applied.taskList.checkboxSize, 20)
        XCTAssertEqual(applied.taskList.checkboxBorderRadius, 5)
        XCTAssertEqual(applied.taskList.checkedStrikethrough, true)
    }

    func testDefaultThemeConfiguresCheckbox() {
        XCTAssertEqual(config.taskList.checkboxSize, 14)
        XCTAssertEqual(config.taskList.checkboxBorderRadius, 3)
        XCTAssertNotNil(config.taskList.checkedColor)
        XCTAssertNotNil(config.taskList.borderColor)
        XCTAssertNotNil(config.taskList.checkmarkColor)
        XCTAssertNil(config.taskList.checkedTextColor)
    }

    func testTaskListStyleMergePrefersOverlay() {
        var base = TaskListStyle(checkedColor: .blue, checkboxSize: 14)
        base.merge(TaskListStyle(checkboxSize: 20, checkedStrikethrough: true))

        XCTAssertEqual(base.checkedColor, .blue)
        XCTAssertEqual(base.checkboxSize, 20)
        XCTAssertEqual(base.checkedStrikethrough, true)
    }
}
