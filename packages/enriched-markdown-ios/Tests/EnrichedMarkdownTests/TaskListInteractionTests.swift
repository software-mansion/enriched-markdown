import Combine
import SwiftUI
import UIKit
import XCTest
@testable import EnrichedMarkdown

final class TaskListInteractionTests: XCTestCase {
    private var config: MarkdownStyleConfig!

    override func setUp() {
        super.setUp()
        config = MarkdownStyleConfig.baseline()
    }

    // MARK: - Source toggling

    func testTogglingSourceChecksTargetItem() {
        let source = "- [ ] first\n- [ ] second"

        let result = TaskListInteraction.togglingSource(source, index: 1, checked: true)

        XCTAssertEqual(result, "- [ ] first\n- [x] second")
    }

    func testTogglingSourceUnchecksTargetItem() {
        let source = "- [x] first\n- [X] second"

        let result = TaskListInteraction.togglingSource(source, index: 0, checked: false)

        XCTAssertEqual(result, "- [ ] first\n- [X] second")
    }

    func testTogglingSourcePreservesMarkerAndIndent() {
        let source = "* [ ] star\n  + [ ] nested plus"

        let result = TaskListInteraction.togglingSource(source, index: 1, checked: true)

        XCTAssertEqual(result, "* [ ] star\n  + [x] nested plus")
    }

    func testTogglingSourceSkipsNonTaskLines() {
        let source = "- plain item\n- [ ] task"

        let result = TaskListInteraction.togglingSource(source, index: 0, checked: true)

        XCTAssertEqual(result, "- plain item\n- [x] task")
    }

    func testTogglingSourceIgnoresOutOfRangeIndex() {
        let source = "- [ ] only"

        XCTAssertEqual(TaskListInteraction.togglingSource(source, index: 1, checked: true), source)
        XCTAssertEqual(TaskListInteraction.togglingSource(source, index: -1, checked: true), source)
    }

    // MARK: - Rendered index attribute

    func testTaskItemsCarryDocumentOrderIndices() {
        let result = MarkdownRenderer.render(
            "- [ ] first\n  - [ ] nested\n- [ ] second",
            config: config
        )
        let string = result.string as NSString

        XCTAssertEqual(taskIndex(in: result, at: string.range(of: "first").location), 0)
        XCTAssertEqual(taskIndex(in: result, at: string.range(of: "nested").location), 1)
        XCTAssertEqual(taskIndex(in: result, at: string.range(of: "second").location), 2)
    }

    func testRegularItemsCarryNoTaskIndex() {
        let result = MarkdownRenderer.render("- plain item", config: config)
        let location = (result.string as NSString).range(of: "plain").location

        XCTAssertNil(result.attribute(MarkdownAttribute.taskListIndex, at: location, effectiveRange: nil))
    }

    // MARK: - Attributed toggling

    func testTogglingItemUpdatesCheckedAttribute() {
        let rendered = MarkdownRenderer.render("- [ ] todo", config: config)

        let toggled = TaskListInteraction.togglingItem(in: rendered, index: 0, checked: true, config: config)

        let location = ((toggled?.string ?? "") as NSString).range(of: "todo").location
        XCTAssertTrue(MarkdownAttributeValue.boolValue(
            from: toggled?.attribute(MarkdownAttribute.taskListItem, at: location, effectiveRange: nil)
        ))
    }

    func testTogglingItemAppliesAndRemovesStrikethrough() {
        config.taskList.checkedStrikethrough = true
        let rendered = MarkdownRenderer.render("- [ ] todo", config: config)
        let location = (rendered.string as NSString).range(of: "todo").location

        let checked = TaskListInteraction.togglingItem(in: rendered, index: 0, checked: true, config: config)
        XCTAssertNotNil(checked?.attribute(.strikethroughStyle, at: location, effectiveRange: nil))

        let unchecked = TaskListInteraction.togglingItem(in: checked!, index: 0, checked: false, config: config)
        XCTAssertNil(unchecked?.attribute(.strikethroughStyle, at: location, effectiveRange: nil))
    }

    func testTogglingItemMatchesFreshRenderOfToggledSource() {
        config.taskList.checkedStrikethrough = true
        let rendered = MarkdownRenderer.render("- [ ] first\n- [ ] second", config: config)

        let toggled = TaskListInteraction.togglingItem(in: rendered, index: 1, checked: true, config: config)
        let fresh = MarkdownRenderer.render("- [ ] first\n- [x] second", config: config)

        XCTAssertEqual(toggled, fresh)
    }

    func testTogglingItemReturnsNilForUnknownIndex() {
        let rendered = MarkdownRenderer.render("- [ ] todo", config: config)

        XCTAssertNil(TaskListInteraction.togglingItem(in: rendered, index: 5, checked: true, config: config))
    }

    // MARK: - Item text

    func testItemTextReturnsFirstLineTrimmed() {
        let rendered = MarkdownRenderer.render("- [ ] buy **milk**\n- [x] done", config: config)

        XCTAssertEqual(TaskListInteraction.itemText(in: rendered, index: 0), "buy milk")
        XCTAssertEqual(TaskListInteraction.itemText(in: rendered, index: 1), "done")
        XCTAssertEqual(TaskListInteraction.itemText(in: rendered, index: 2), "")
    }

    // MARK: - Hit testing

    func testHitInLeadingMarginFindsItem() {
        let textView = makeLaidOutTextView("- [ ] todo")

        let hit = textView.taskListHit(at: CGPoint(x: 4, y: 8))

        XCTAssertEqual(hit?.index, 0)
        XCTAssertEqual(hit?.checked, false)
        XCTAssertEqual(hit?.itemText, "todo")
    }

    func testHitReportsCheckedState() {
        let textView = makeLaidOutTextView("- [x] done")

        XCTAssertEqual(textView.taskListHit(at: CGPoint(x: 4, y: 8))?.checked, true)
    }

    func testHitInTextAreaReturnsNil() {
        let textView = makeLaidOutTextView("- [ ] todo")

        XCTAssertNil(textView.taskListHit(at: CGPoint(x: 200, y: 8)))
    }

    func testHitOnNonTaskParagraphReturnsNil() {
        let textView = makeLaidOutTextView("- plain item")

        XCTAssertNil(textView.taskListHit(at: CGPoint(x: 4, y: 8)))
    }

    // MARK: - Render store

    @MainActor
    func testStoreToggleUpdatesTextAndSource() {
        let store = MarkdownRenderStore()
        renderSynchronously(store, markdown: "- [ ] todo")

        store.applyTaskListToggle(index: 0, checked: true, config: config)

        XCTAssertEqual(store.source?.markdown, "- [x] todo")
        let location = (store.attributedText.string as NSString).range(of: "todo").location
        XCTAssertTrue(MarkdownAttributeValue.boolValue(
            from: store.attributedText.attribute(MarkdownAttribute.taskListItem, at: location, effectiveRange: nil)
        ))
    }

    @MainActor
    func testStoreRescheduleOfSameBaseKeepsToggle() {
        let store = MarkdownRenderStore()
        renderSynchronously(store, markdown: "- [ ] todo")
        store.applyTaskListToggle(index: 0, checked: true, config: config)

        renderSynchronously(store, markdown: "- [ ] todo")

        XCTAssertEqual(store.source?.markdown, "- [x] todo")
    }

    @MainActor
    func testStoreRescheduleOfNewBaseDropsToggle() {
        let store = MarkdownRenderStore()
        renderSynchronously(store, markdown: "- [ ] todo")
        store.applyTaskListToggle(index: 0, checked: true, config: config)

        renderSynchronously(store, markdown: "- [ ] rewritten")

        XCTAssertEqual(store.source?.markdown, "- [ ] rewritten")
    }

    // MARK: - Defaults

    func testEnvironmentDefaults() {
        let environment = EnvironmentValues()

        XCTAssertNil(environment.markdownTaskListItemPressHandler)
        XCTAssertTrue(environment.markdownTaskListItemToggleEnabled)
    }

    // MARK: - Helpers

    private func taskIndex(in attributedText: NSAttributedString, at location: Int) -> Int? {
        MarkdownAttributeValue.intValue(
            from: attributedText.attribute(MarkdownAttribute.taskListIndex, at: location, effectiveRange: nil)
        )
    }

    private func makeLaidOutTextView(_ markdown: String, width: CGFloat = 320) -> MarkdownTextView {
        let textView = MarkdownTextView()
        textView.setMarkdownAttributedText(MarkdownRenderer.render(markdown, config: config))
        textView.frame = CGRect(x: 0, y: 0, width: width, height: 400)
        textView.layoutIfNeeded()
        if let textLayoutManager = textView.textLayoutManager {
            textLayoutManager.ensureLayout(for: textLayoutManager.documentRange)
        }
        return textView
    }

    @MainActor
    private func renderSynchronously(_ store: MarkdownRenderStore, markdown: String) {
        store.schedule(markdown: markdown, config: config)
        let rendered = expectation(description: "render applied for \(markdown)")
        let cancellable = store.$source
            .dropFirst()
            .sink { _ in rendered.fulfill() }
        wait(for: [rendered], timeout: 2)
        cancellable.cancel()
    }
}
