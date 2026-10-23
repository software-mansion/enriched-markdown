import SwiftUI
import UIKit
import XCTest
@testable import EnrichedMarkdown
@testable import EnrichedMarkdownStreaming

@MainActor
final class StreamingTextViewTests: XCTestCase {
    private var window: UIWindow?
    private let streaming = MarkdownStreamingOptions()

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    private func makeTextView(width: CGFloat = 600) -> MarkdownTextView {
        let textView = MarkdownTextView()
        textView.styleConfig = .baseline()
        textView.frame = CGRect(x: 0, y: 0, width: width, height: 2000)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: 2000))
        window.addSubview(textView)
        window.isHidden = false
        self.window = window
        return textView
    }

    private func makeScrolledTextView(width: CGFloat, height: CGFloat, windowHeight: CGFloat) -> MarkdownTextView {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: windowHeight))
        let scrollView = UIScrollView(frame: window.bounds)
        let textView = MarkdownTextView()
        textView.styleConfig = .baseline()
        textView.frame = CGRect(x: 0, y: 0, width: width, height: height)
        scrollView.addSubview(textView)
        window.addSubview(scrollView)
        window.isHidden = false
        self.window = window
        return textView
    }

    func testEnvironmentDefault() {
        XCTAssertNil(EnvironmentValues().markdownStreaming)
        XCTAssertEqual(MarkdownStreamingOptions(), MarkdownStreamingOptions(tables: .progressive, codeBlocks: .progressive, transition: .opacity))
    }

    func testOptionsCompareTransitionsByValue() {
        XCTAssertEqual(MarkdownStreamingOptions(transition: .opacity(duration: 1)), MarkdownStreamingOptions(transition: .opacity(duration: 1)))
        XCTAssertNotEqual(MarkdownStreamingOptions(transition: .opacity), MarkdownStreamingOptions(transition: .opacity(duration: 1)))
        XCTAssertNotEqual(MarkdownStreamingOptions(transition: .opacity), MarkdownStreamingOptions(transition: .identity))
    }

    func testStreamingEditsMatchAssigningTheWholeText() {
        let textView = makeTextView()
        let reference = MarkdownTextView()
        let session = StreamingFixtures.session()
        for prefix in StreamingFixtures.chunks(of: StreamingFixtures.answer) {
            let result = session.render(prefix, options: streaming)
            textView.setMarkdownAttributedText(result.text, lineage: result.lineage)
            reference.setMarkdownAttributedText(result.text)
            XCTAssertTrue(
                AttributedTextDiff.isEquivalent(textView.textStorage, reference.textStorage),
                "storage diverged after \(prefix.suffix(20).debugDescription)"
            )
        }
    }

    func testStreamingEditsReplaceOnlyTheTail() {
        let textView = makeTextView()
        let session = StreamingFixtures.session()
        let first = session.render("First paragraph.\n\nSecond paragraph", options: streaming)
        textView.setMarkdownAttributedText(first.text, lineage: first.lineage)

        let storage = textView.textStorage
        var edits: [NSRange] = []
        let observer = NotificationCenter.default.addObserver(
            forName: NSTextStorage.didProcessEditingNotification,
            object: storage,
            queue: nil
        ) { _ in
            MainActor.assumeIsolated {
                edits.append(storage.editedRange)
            }
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        let second = session.render("First paragraph.\n\nSecond paragraph grows", options: streaming)
        textView.setMarkdownAttributedText(second.text, lineage: second.lineage)

        let firstParagraphEnd = (second.text.string as NSString).range(of: "Second").location
        XCTAssertEqual(edits.count, 1)
        XCTAssertGreaterThanOrEqual(edits.first?.location ?? 0, firstParagraphEnd)
    }

    func testSelectionSurvivesStreamingEdits() {
        let textView = makeTextView()
        let session = StreamingFixtures.session()
        let first = session.render("First paragraph.\n\nSecond", options: streaming)
        textView.setMarkdownAttributedText(first.text, lineage: first.lineage)
        _ = textView.becomeFirstResponder()
        let selection = (first.text.string as NSString).range(of: "First")
        textView.selectedRange = selection

        let second = session.render("First paragraph.\n\nSecond paragraph and more", options: streaming)
        textView.setMarkdownAttributedText(second.text, lineage: second.lineage)

        XCTAssertEqual(textView.selectedRange, selection)
    }

    func testStableTableKeepsItsView() throws {
        let textView = makeTextView(width: 380)
        let session = StreamingFixtures.session()
        let table = "| A | B |\n|---|---|\n| 1 | 2 |\n\n"
        let first = session.render(table + "Next", options: streaming)
        textView.setMarkdownAttributedText(first.text, lineage: first.lineage)
        settle(textView)
        let before = try XCTUnwrap(textView.firstSubview(of: TableAttachmentView.self))

        let second = session.render(table + "Next paragraph grows", options: streaming)
        textView.setMarkdownAttributedText(second.text, lineage: second.lineage)
        settle(textView)

        XCTAssertTrue(try XCTUnwrap(textView.firstSubview(of: TableAttachmentView.self)) === before)
        XCTAssertTrue(textView.textStorage.string.contains("Next paragraph grows"))
    }

    func testClosedCodeBlockKeepsItsPendingPanel() throws {
        let textView = makeTextView(width: 380)
        let session = StreamingFixtures.session(codeBlockLayout: .scrollable)
        let open = session.render("```swift\nlet x = 1\n", options: streaming)
        textView.setMarkdownAttributedText(open.text, lineage: open.lineage)
        settle(textView)
        let panel = try XCTUnwrap(textView.firstSubview(of: CodeBlockAttachmentView.self))
        let button = try XCTUnwrap(panel.firstSubview(of: UIButton.self))
        XCTAssertFalse(button.isEnabled)

        let closed = session.render("```swift\nlet x = 1\n```", options: streaming)
        textView.setMarkdownAttributedText(closed.text, lineage: closed.lineage)
        settle(textView)
        XCTAssertTrue(try XCTUnwrap(textView.firstSubview(of: CodeBlockAttachmentView.self)) === panel)
        XCTAssertTrue(button.isEnabled)
    }

    func testReplacedProviderLeavesTheSharedViewInPlace() throws {
        let rendered = MarkdownRenderer.render("| A | B |\n|---|---|\n| 1 | 2 |", config: .baseline())
        let attachment = try XCTUnwrap(attachments(of: TableAttachment.self, in: rendered).first)
        let location = NSTextContentStorage().documentRange.location
        var first: TableAttachmentViewProvider? = TableAttachmentViewProvider(
            textAttachment: attachment, parentView: nil, textLayoutManager: nil, location: location
        )
        let view = try XCTUnwrap(first?.view)
        let host = UIView()
        host.addSubview(view)
        let second = TableAttachmentViewProvider(
            textAttachment: attachment, parentView: nil, textLayoutManager: nil, location: location
        )
        XCTAssertTrue(second.view === view)

        first = nil
        XCTAssertTrue(view.superview === host, "the replaced provider's dealloc must not pull the shared view out")
        withExtendedLifetime(second) {}
    }

    func testUnreplacedProviderRemovesItsViewWhenReleased() throws {
        let rendered = MarkdownRenderer.render("| A | B |\n|---|---|\n| 1 | 2 |", config: .baseline())
        let attachment = try XCTUnwrap(attachments(of: TableAttachment.self, in: rendered).first)
        let location = NSTextContentStorage().documentRange.location
        var provider: TableAttachmentViewProvider? = TableAttachmentViewProvider(
            textAttachment: attachment, parentView: nil, textLayoutManager: nil, location: location
        )
        let view = try XCTUnwrap(provider?.view)
        let host = UIView()
        host.addSubview(view)

        provider = nil
        XCTAssertNil(view.superview, "the provider that still owns the view lets UIKit remove it")
    }

    func testOpenTableKeepsItsViewWhileRowsArrive() throws {
        let textView = makeTextView(width: 380)
        let session = StreamingFixtures.session()
        let first = session.render("| A | B |\n|---|---|\n| 1 | 2 |", options: streaming)
        textView.setMarkdownAttributedText(first.text, lineage: first.lineage)
        settle(textView)
        let panel = try XCTUnwrap(textView.firstSubview(of: TableAttachmentView.self))
        let grid = try XCTUnwrap(panel.firstSubview(of: TableGridView.self))
        let height = grid.bounds.height

        let second = session.render("| A | B |\n|---|---|\n| 1 | 2 |\n| 3 | 4 |", options: streaming)
        textView.setMarkdownAttributedText(second.text, lineage: second.lineage)
        settle(textView)

        XCTAssertTrue(try XCTUnwrap(textView.firstSubview(of: TableAttachmentView.self)) === panel)
        let attachment = try XCTUnwrap(attachments(of: TableAttachment.self, in: textView.textStorage).first)
        XCTAssertEqual(grid.bounds.height, attachment.layout.totalHeight)
        XCTAssertGreaterThan(grid.bounds.height, height)
        XCTAssertNotNil(inkBounds(of: snapshot(of: grid), in: firstCellText(ofRow: 2, in: grid, of: attachment)), "the new row is drawn")
    }

    func testOpenCodePanelKeepsItsViewWhileCodeArrives() throws {
        let textView = makeTextView(width: 380)
        let session = StreamingFixtures.session(codeBlockLayout: .scrollable)
        let first = session.render("```swift\nlet x = 1\n", options: streaming)
        textView.setMarkdownAttributedText(first.text, lineage: first.lineage)
        settle(textView)
        let panel = try XCTUnwrap(textView.firstSubview(of: CodeBlockAttachmentView.self))
        let height = panel.bounds.height

        let second = session.render("```swift\nlet x = 1\nlet y = 2\n", options: streaming)
        textView.setMarkdownAttributedText(second.text, lineage: second.lineage)
        settle(textView)

        XCTAssertTrue(try XCTUnwrap(textView.firstSubview(of: CodeBlockAttachmentView.self)) === panel)
        XCTAssertGreaterThan(panel.bounds.height, height)
        let pane = try XCTUnwrap(panel.firstSubview(of: CodeBlockContentView.self))
        let attachment = try XCTUnwrap(attachments(of: CodeBlockAttachment.self, in: textView.textStorage).first)
        XCTAssertEqual(pane.attributedCode.string, "let x = 1\nlet y = 2")
        XCTAssertTrue(AttributedTextDiff.isEquivalent(pane.attributedCode, attachment.attributedCode))
    }

    func testScrolledCodePanelKeepsItsOffsetAcrossChunks() throws {
        let textView = makeTextView(width: 380)
        let session = StreamingFixtures.session(codeBlockLayout: .scrollable)
        let longLine = String(repeating: "x", count: 400)
        let first = session.render("```\n\(longLine)\n", options: streaming)
        textView.setMarkdownAttributedText(first.text, lineage: first.lineage)
        settle(textView)
        let panel = try XCTUnwrap(textView.firstSubview(of: CodeBlockAttachmentView.self))
        let scrollView = try XCTUnwrap(panel.firstSubview(of: UIScrollView.self))
        scrollView.contentOffset = CGPoint(x: 120, y: 0)

        let second = session.render("```\n\(longLine)\nmore\n", options: streaming)
        textView.setMarkdownAttributedText(second.text, lineage: second.lineage)
        settle(textView)

        XCTAssertTrue(try XCTUnwrap(textView.firstSubview(of: CodeBlockAttachmentView.self)) === panel)
        XCTAssertEqual(scrollView.contentOffset.x, 120)
    }

    func testNewTableRowsFadeInsideThePanel() throws {
        try XCTSkipIf(UIAccessibility.isReduceMotionEnabled)
        let textView = makeTextView(width: 380)
        let recorder = TransitionRecorder()
        let session = StreamingFixtures.session()
        let first = session.render("| A | B |\n|---|---|\n| 1 | 2 |", options: streaming)
        textView.setMarkdownAttributedText(first.text, lineage: first.lineage)
        settle(textView)
        textView.streamingTransitions.transition = RecordingTransition(recorder: recorder, holds: true).viewTransition

        let second = session.render("| A | B |\n|---|---|\n| 1 | 2 |\n| 3 | 4 |", options: streaming)
        textView.setMarkdownAttributedText(second.text, lineage: second.lineage)
        settle(textView)

        let panel = try XCTUnwrap(textView.firstSubview(of: TableAttachmentView.self))
        let grid = try XCTUnwrap(panel.firstSubview(of: TableGridView.self))
        let overlay = try XCTUnwrap(recorder.views.last as? UIImageView)
        XCTAssertEqual(recorder.views.count, 1)
        XCTAssertTrue(overlay.isDescendant(of: panel))
        XCTAssertEqual(overlay.convert(overlay.bounds, to: grid), grid.rowRect(2), accuracy: 1)
        let attachment = try XCTUnwrap(attachments(of: TableAttachment.self, in: textView.textStorage).first)
        let newText = firstCellText(ofRow: 2, in: grid, of: attachment)
        let oldText = firstCellText(ofRow: 1, in: grid, of: attachment)
        XCTAssertNil(inkBounds(of: snapshot(of: grid), in: newText), "the new row's text waits under its overlay")
        XCTAssertNotNil(inkBounds(of: snapshot(of: grid), in: oldText), "earlier rows stay drawn")
        let image = try XCTUnwrap(overlay.image)
        XCTAssertNotNil(inkBounds(of: image, in: CGRect(origin: .zero, size: overlay.bounds.size)), "the overlay draws the new row")

        recorder.completions.forEach { $0() }
        grid.layer.displayIfNeeded()
        XCTAssertNil(overlay.superview)
        XCTAssertNotNil(inkBounds(of: snapshot(of: grid), in: newText))
    }

    func testAppendedCodeFadesInsideThePanel() throws {
        try XCTSkipIf(UIAccessibility.isReduceMotionEnabled)
        let textView = makeTextView(width: 380)
        let recorder = TransitionRecorder()
        let session = StreamingFixtures.session(codeBlockLayout: .scrollable)
        let first = session.render("```swift\nlet x = 1\n", options: streaming)
        textView.setMarkdownAttributedText(first.text, lineage: first.lineage)
        settle(textView)
        textView.streamingTransitions.transition = RecordingTransition(recorder: recorder, holds: true).viewTransition

        let second = session.render("```swift\nlet x = 1\nlet y = 2", options: streaming)
        textView.setMarkdownAttributedText(second.text, lineage: second.lineage)
        settle(textView)

        let panel = try XCTUnwrap(textView.firstSubview(of: CodeBlockAttachmentView.self))
        let pane = try XCTUnwrap(panel.firstSubview(of: CodeBlockContentView.self))
        let appended = (pane.attributedCode.string as NSString).range(of: "let y = 2")
        XCTAssertEqual(pane.attributedCode.color(at: appended.location)?.cgColor.alpha, 0)
        XCTAssertNotEqual(pane.attributedCode.color(at: 0)?.cgColor.alpha, 0)
        let overlay = try XCTUnwrap(recorder.views.last as? UIImageView)
        XCTAssertEqual(recorder.views.count, 1)
        XCTAssertTrue(overlay.isDescendant(of: panel))
        let line = try XCTUnwrap(pane.lineSegments(of: appended).first)
        XCTAssertEqual(overlay.convert(overlay.bounds, to: pane), line.frame, accuracy: 1)

        recorder.completions.forEach { $0() }
        XCTAssertNil(overlay.superview)
        let attachment = try XCTUnwrap(attachments(of: CodeBlockAttachment.self, in: textView.textStorage).first)
        XCTAssertTrue(AttributedTextDiff.isEquivalent(pane.attributedCode, attachment.attributedCode))
    }

    func testIdentityTransitionShowsNewRowsAtOnce() throws {
        let textView = makeTextView(width: 380)
        textView.streamingTransitions.transition = IdentityStreamingTransition().viewTransition
        let session = StreamingFixtures.session()
        let first = session.render("| A | B |\n|---|---|\n| 1 | 2 |", options: streaming)
        textView.setMarkdownAttributedText(first.text, lineage: first.lineage)
        settle(textView)

        let second = session.render("| A | B |\n|---|---|\n| 1 | 2 |\n| 3 | 4 |", options: streaming)
        textView.setMarkdownAttributedText(second.text, lineage: second.lineage)
        settle(textView)

        let panel = try XCTUnwrap(textView.firstSubview(of: TableAttachmentView.self))
        let grid = try XCTUnwrap(panel.firstSubview(of: TableGridView.self))
        XCTAssertTrue(grid.concealedRows.isEmpty)
        XCTAssertNil(panel.firstSubview(of: UIImageView.self))
    }

    func testFadeRestoresTheStorageColorsWhenDone() throws {
        try XCTSkipIf(UIAccessibility.isReduceMotionEnabled)
        let textView = makeTextView()
        let session = StreamingFixtures.session()
        let first = session.render("Hello", options: streaming)
        textView.setMarkdownAttributedText(first.text, lineage: first.lineage)
        textView.streamingTransitions.transition = OpacityStreamingTransition().viewTransition
        let second = session.render("Hello world, this is new", options: streaming)
        textView.setMarkdownAttributedText(second.text, lineage: second.lineage)

        let newText = (second.text.string as NSString).range(of: "this is new")
        let oldText = (second.text.string as NSString).range(of: "Hello")
        XCTAssertEqual(textView.textStorage.color(at: newText.location)?.cgColor.alpha, 0)
        XCTAssertEqual(textView.textStorage.color(at: oldText.location), second.text.color(at: newText.location))

        drainMainQueue(for: OpacityStreamingTransition().duration + 0.15)
        XCTAssertTrue(AttributedTextDiff.isEquivalent(textView.textStorage, MarkdownTextView().storage(showing: second.text)))
    }

    func testHiddenLinksAndStrikethroughsKeepNoColorEither() throws {
        try XCTSkipIf(UIAccessibility.isReduceMotionEnabled)
        let textView = makeTextView()
        textView.streamingTransitions.transition = RecordingTransition(recorder: TransitionRecorder(), holds: true).viewTransition
        var config = MarkdownStyleConfiguration.baseline()
        config.link.foregroundColor = .systemBlue
        config.taskList.checkedStrikethrough = true
        let text = MarkdownRenderer.render("- [x] done [link](https://example.com)", config: config)
        textView.setMarkdownAttributedText(text)
        let link = (text.string as NSString).range(of: "link")
        let done = (text.string as NSString).range(of: "done")

        textView.streamingTransitions.insert(NSRange(location: 0, length: text.length))
        XCTAssertEqual(textView.textStorage.attribute(.underlineColor, at: link.location, effectiveRange: nil) as? UIColor, .clear)
        XCTAssertEqual(textView.textStorage.attribute(.strikethroughColor, at: done.location, effectiveRange: nil) as? UIColor, .clear)

        textView.streamingTransitions.textWillChange(from: 0)
        XCTAssertTrue(AttributedTextDiff.isEquivalent(textView.textStorage, MarkdownTextView().storage(showing: text)))
    }

    func testFirstRenderOfASessionTransitionsAsAWhole() throws {
        try XCTSkipIf(UIAccessibility.isReduceMotionEnabled)
        let textView = makeTextView()
        textView.streamingTransitions.transition = OpacityStreamingTransition().viewTransition
        let first = StreamingFixtures.session().render("Hello", options: streaming)
        textView.setMarkdownAttributedText(first.text, lineage: first.lineage)

        XCTAssertEqual(textView.textStorage.color(at: 0)?.cgColor.alpha, 0)
        drainMainQueue(for: OpacityStreamingTransition().duration + 0.15)
        XCTAssertTrue(AttributedTextDiff.isEquivalent(textView.textStorage, MarkdownTextView().storage(showing: first.text)))
    }

    func testFadedTextIsDrawnTransparentThenOpaque() throws {
        try XCTSkipIf(UIAccessibility.isReduceMotionEnabled)
        let (textView, tailRect) = try streamedTail(transition: .opacity)

        XCTAssertNil(inkBounds(of: snapshot(of: textView, presentation: true), in: tailRect), "new text starts transparent")
        let helloRect = CGRect(x: 0, y: tailRect.minY, width: tailRect.minX - 4, height: tailRect.height)
        XCTAssertNotNil(inkBounds(of: snapshot(of: textView, presentation: true), in: helloRect), "earlier text stays drawn")

        drainMainQueue(for: OpacityStreamingTransition().duration + 0.15)
        XCTAssertNotNil(inkBounds(of: snapshot(of: textView), in: tailRect), "new text ends drawn")
    }

    func testIdentityTransitionDrawsNewTextAtOnce() throws {
        let (textView, tailRect) = try streamedTail(transition: .identity)
        XCTAssertNotNil(inkBounds(of: snapshot(of: textView), in: tailRect))
    }

    func testCustomTransitionAnimatesNewSegmentsAndBlockContent() throws {
        try XCTSkipIf(UIAccessibility.isReduceMotionEnabled)
        let textView = makeTextView(width: 380)
        let recorder = TransitionRecorder()
        let session = StreamingFixtures.session()
        let first = session.render("Hello", options: streaming)
        textView.setMarkdownAttributedText(first.text, lineage: first.lineage)
        textView.streamingTransitions.transition = RecordingTransition(recorder: recorder, holds: true).viewTransition

        let second = session.render("Hello world\n\n| A | B |\n|---|---|\n| 1 | 2 |\n\nNext", options: streaming)
        textView.setMarkdownAttributedText(second.text, lineage: second.lineage)
        settle(textView)

        let views = recorder.views.compactMap { $0 as? UIImageView }
        XCTAssertEqual(views.count, recorder.views.count, "every animated view is a snapshot")
        let words = try rect(of: " world", in: textView)
        let tail = try rect(of: "Next", in: textView)
        XCTAssertTrue(views.contains { $0.superview === textView && $0.frame.intersects(words) }, "the new words get a segment view")
        XCTAssertTrue(views.contains { $0.superview === textView && $0.frame.intersects(tail) }, "the tail gets a segment view")
        let panel = try XCTUnwrap(textView.firstSubview(of: TableAttachmentView.self))
        XCTAssertEqual(views.filter { $0.isDescendant(of: panel) }.count, 2, "each table row gets its own view inside the panel")

        recorder.completions.forEach { $0() }
        XCTAssertTrue(views.allSatisfy { $0.superview == nil }, "a completed view is removed")
        XCTAssertTrue(AttributedTextDiff.isEquivalent(textView.textStorage, MarkdownTextView().storage(showing: second.text)))
    }

    func testHeldSegmentViewsMoveWithTheirText() throws {
        try XCTSkipIf(UIAccessibility.isReduceMotionEnabled)
        let recorder = TransitionRecorder()
        let (textView, tailRect) = try streamedTail(transition: RecordingTransition(recorder: recorder, holds: true))
        let overlay = try XCTUnwrap(recorder.views.last as? UIImageView)
        XCTAssertEqual(overlay.frame.midY, tailRect.midY, accuracy: 2)

        textView.textContainerInset.top += 20
        textView.setNeedsLayout()
        textView.layoutIfNeeded()

        XCTAssertEqual(overlay.frame.midY, tailRect.midY + 20, accuracy: 2)
        XCTAssertTrue(overlay.superview === textView)
        recorder.completions.forEach { $0() }
        XCTAssertNil(overlay.superview)
    }

    func testHeldSegmentViewsAreRebuiltWhenTheirTextRewraps() throws {
        try XCTSkipIf(UIAccessibility.isReduceMotionEnabled)
        let recorder = TransitionRecorder()
        let (textView, _) = try streamedTail(transition: RecordingTransition(recorder: recorder, holds: true))
        let overlay = try XCTUnwrap(recorder.views.last as? UIImageView)

        textView.frame.size.width = 100
        textView.layoutIfNeeded()

        XCTAssertNil(overlay.superview)
        let wrapped = try rect(of: "WWWWWWWW", in: textView)
        XCTAssertTrue(recorder.views.contains { $0.superview === textView && $0.frame.intersects(wrapped) })
    }

    func testSegmentViewsLineUpWithTheTextTheyStandFor() throws {
        try XCTSkipIf(UIAccessibility.isReduceMotionEnabled)
        try assertSegmentViewLinesUp(from: "Hello", to: "Hello WWWWWWWW")
        try assertSegmentViewLinesUp(from: "- item", to: "- item `code` **bold** tail")
        try assertSegmentViewLinesUp(from: "> quoted", to: "> quoted ==mark== more")
        try assertSegmentViewLinesUp(from: "שלום", to: "שלום עולם רחב")
    }

    func testSegmentViewsLandOnTheTailOfADocumentTallerThanTheWindow() throws {
        try XCTSkipIf(UIAccessibility.isReduceMotionEnabled)
        let textView = makeScrolledTextView(width: 400, height: 5000, windowHeight: 500)
        let recorder = TransitionRecorder()
        let session = StreamingFixtures.session()
        let body = (1...60).map { "Paragraph number \($0) of a long answer." }.joined(separator: "\n\n")
        let first = session.render(body + "\n\nTail", options: streaming)
        textView.setMarkdownAttributedText(first.text, lineage: first.lineage)
        textView.layoutIfNeeded()
        textView.streamingTransitions.transition = RecordingTransition(recorder: recorder, holds: true).viewTransition

        let second = session.render(body + "\n\nTail grows here", options: streaming)
        textView.setMarkdownAttributedText(second.text, lineage: second.lineage)
        textView.layoutIfNeeded()

        let overlay = try XCTUnwrap(recorder.views.last as? UIImageView)
        let tail = try rect(of: " grows here", in: textView)
        XCTAssertEqual(overlay.frame, tail, accuracy: 2)
    }

    func testEveryChunkOfTheSampleAnswerGetsItsSegmentViewOnItsOwnLine() throws {
        try XCTSkipIf(UIAccessibility.isReduceMotionEnabled)
        let textView = makeScrolledTextView(width: 390, height: 5000, windowHeight: 600)
        let recorder = TransitionRecorder()
        textView.streamingTransitions.transition = RecordingTransition(recorder: recorder, holds: true).viewTransition
        let session = StreamingFixtures.session(options: MarkdownParsingOptions(admonitions: true), codeBlockLayout: .scrollable)

        for prefix in StreamingFixtures.chunks(of: StreamingFixtures.sampleAnswer, sizes: [6]) {
            let result = session.render(prefix, options: streaming)
            textView.setMarkdownAttributedText(result.text, lineage: result.lineage)
            textView.layoutIfNeeded()
            guard textView.textStorage.string.last?.isLetter == true,
                  let overlay = recorder.views.last(where: { $0.superview != nil }) as? UIImageView
            else { continue }
            let last = try rect(of: NSRange(location: textView.textStorage.length - 1, length: 1), in: textView)
            XCTAssertEqual(
                overlay.frame.midY, last.midY, accuracy: 40,
                "after \(prefix.count) chars: overlay \(overlay.frame) vs last character \(last)"
            )
        }
    }

    func testReplacedTextIsRestoredBeforeTheEditOverwritesIt() throws {
        try XCTSkipIf(UIAccessibility.isReduceMotionEnabled)
        let textView = makeTextView()
        textView.streamingTransitions.transition = RecordingTransition(recorder: TransitionRecorder(), holds: true).viewTransition
        let text = MarkdownRenderer.render("Hello world", config: .baseline())
        textView.setMarkdownAttributedText(text)
        let world = (text.string as NSString).range(of: "world")

        textView.streamingTransitions.insert(world)
        XCTAssertEqual(textView.textStorage.color(at: world.location)?.cgColor.alpha, 0)

        textView.streamingTransitions.textWillChange(from: world.location + 2)
        XCTAssertEqual(textView.textStorage.color(at: world.location)?.cgColor.alpha, 0, "the kept part stays hidden")
        XCTAssertEqual(textView.textStorage.color(at: world.location + 2), text.color(at: world.location))
    }

    func testNewSessionWithTheSameContentDoesNotFadeTheDocumentAgain() throws {
        try XCTSkipIf(UIAccessibility.isReduceMotionEnabled)
        let textView = makeTextView(width: 380)
        let markdown = "# Title\n\n| A | B |\n|---|---|\n| 1 | 2 |\n\nStreamed **answer"
        let first = StreamingFixtures.session().render(markdown, options: streaming)
        textView.setMarkdownAttributedText(first.text, lineage: first.lineage)
        settle(textView)
        let panel = try XCTUnwrap(textView.firstSubview(of: TableAttachmentView.self))

        let second = StreamingFixtures.session().render(markdown, options: streaming)
        XCTAssertNotEqual(first.lineage.session, second.lineage.session)
        textView.setMarkdownAttributedText(second.text, lineage: second.lineage)
        textView.layoutIfNeeded()

        XCTAssertNotEqual(textView.textStorage.color(at: 0)?.cgColor.alpha, 0, "unchanged text is not concealed again")
        XCTAssertTrue(AttributedTextDiff.isEquivalent(textView.textStorage, MarkdownTextView().storage(showing: second.text)))
        XCTAssertTrue(textView.firstSubview(of: TableAttachmentView.self) === panel)
    }

    func testTintedLinksDrawAndFadeInTheViewsTint() throws {
        try XCTSkipIf(UIAccessibility.isReduceMotionEnabled)
        let textView = makeTextView(width: 380)
        textView.tintColor = .systemRed
        var config = MarkdownStyleConfiguration.baseline()
        config.link.foregroundColor = UIColor.tintColor
        let session = StreamingFixtures.session(config: config)
        let recorder = TransitionRecorder()
        let first = session.render("Hello", options: streaming)
        textView.setMarkdownAttributedText(first.text, lineage: first.lineage)
        settle(textView)
        textView.streamingTransitions.transition = RecordingTransition(recorder: recorder, holds: true).viewTransition

        let second = session.render("Hello [link](https://example.com)", options: streaming)
        textView.setMarkdownAttributedText(second.text, lineage: second.lineage)
        textView.layoutIfNeeded()

        let overlay = try XCTUnwrap(recorder.views.last as? UIImageView)
        let image = try XCTUnwrap(overlay.image)
        XCTAssertNotNil(
            inkBounds(of: image, in: CGRect(origin: .zero, size: overlay.bounds.size), matching: .systemRed),
            "the segment snapshot uses the view's tint"
        )
        recorder.completions.forEach { $0() }
        let link = try rect(of: "link", in: textView)
        XCTAssertNotNil(inkBounds(of: snapshot(of: textView), in: link, matching: .systemRed), "the text view draws the link in its tint")
    }

    func testTextWithoutLineageReplacesTheDocument() {
        let textView = makeTextView()
        let streamed = StreamingFixtures.session().render("Streamed **answer", options: streaming)
        textView.setMarkdownAttributedText(streamed.text, lineage: streamed.lineage)

        let plain = MarkdownRenderer.render("Something else", config: .baseline())
        textView.setMarkdownAttributedText(plain)
        XCTAssertEqual(textView.textStorage.string, plain.string)
    }

    func testTextWithoutLineageEndsAFadeAtFullColor() throws {
        try XCTSkipIf(UIAccessibility.isReduceMotionEnabled)
        let textView = makeTextView()
        textView.streamingTransitions.transition = OpacityStreamingTransition().viewTransition
        let first = StreamingFixtures.session().render("Hello", options: streaming)
        textView.setMarkdownAttributedText(first.text, lineage: first.lineage)

        let plain = MarkdownRenderer.render("Something else", config: .baseline())
        textView.setMarkdownAttributedText(plain)

        XCTAssertTrue(AttributedTextDiff.isEquivalent(textView.textStorage, MarkdownTextView().storage(showing: plain)))
    }

    private func streamedTail(transition: any MarkdownStreamingTransition) throws -> (MarkdownTextView, CGRect) {
        let textView = makeTextView()
        let session = StreamingFixtures.session()
        let first = session.render("Hello", options: streaming)
        textView.setMarkdownAttributedText(first.text, lineage: first.lineage)
        textView.streamingTransitions.transition = transition.viewTransition
        let second = session.render("Hello WWWWWWWW", options: streaming)
        textView.setMarkdownAttributedText(second.text, lineage: second.lineage)
        textView.layoutIfNeeded()
        return (textView, try rect(of: "WWWWWWWW", in: textView).insetBy(dx: 1, dy: 1).integral)
    }

    private func assertSegmentViewLinesUp(from first: String, to second: String) throws {
        let textView = makeTextView()
        let recorder = TransitionRecorder()
        var config = MarkdownStyleConfiguration.baseline()
        config.blockquote.foregroundColor = .black
        let session = StreamingFixtures.session(config: config, options: MarkdownParsingOptions(highlight: true))
        let start = session.render(first, options: streaming)
        textView.setMarkdownAttributedText(start.text, lineage: start.lineage)
        textView.streamingTransitions.transition = RecordingTransition(recorder: recorder, holds: true).viewTransition
        let end = session.render(second, options: streaming)
        textView.setMarkdownAttributedText(end.text, lineage: end.lineage)
        textView.layoutIfNeeded()

        let overlay = try XCTUnwrap(recorder.views.last as? UIImageView, second)
        let frame = overlay.frame
        let canvas = CGRect(origin: .zero, size: frame.size)
        let textColor = try XCTUnwrap(end.text.color(at: end.text.length - 1))
        let drawn = try XCTUnwrap(inkBounds(of: try XCTUnwrap(overlay.image), in: canvas, matching: textColor), second)
        recorder.completions.forEach { $0() }
        let real = try XCTUnwrap(inkBounds(of: snapshot(of: textView), in: frame, matching: textColor), second)
        XCTAssertEqual(drawn, real, accuracy: 1, second)
    }

    private func rect(of text: String, in textView: UITextView) throws -> CGRect {
        try rect(of: (textView.textStorage.string as NSString).range(of: text), in: textView)
    }

    private func rect(of range: NSRange, in textView: UITextView) throws -> CGRect {
        let start = try XCTUnwrap(textView.position(from: textView.beginningOfDocument, offset: range.location))
        let end = try XCTUnwrap(textView.position(from: start, offset: range.length))
        return textView.firstRect(for: try XCTUnwrap(textView.textRange(from: start, to: end)))
    }

    private func settle(_ textView: MarkdownTextView) {
        textView.frame.size.height = height(of: textView, width: textView.bounds.width)
        textView.layoutIfNeeded()
        drainMainQueue()
        textView.layoutIfNeeded()
    }

    private func firstCellText(ofRow row: Int, in grid: TableGridView, of attachment: TableAttachment) -> CGRect {
        let rowRect = grid.rowRect(row)
        let horizontal = attachment.style.cellPaddingHorizontal
        let vertical = attachment.style.cellPaddingVertical
        return CGRect(
            x: horizontal,
            y: rowRect.minY + vertical,
            width: attachment.layout.columnWidths[0] - horizontal * 2,
            height: rowRect.height - vertical * 2
        )
    }
}

private extension MarkdownTextView {
    func storage(showing text: NSAttributedString) -> NSTextStorage {
        setMarkdownAttributedText(text)
        return textStorage
    }
}

private extension NSAttributedString {
    func color(at location: Int) -> UIColor? {
        attribute(.foregroundColor, at: location, effectiveRange: nil) as? UIColor
    }
}

@MainActor
private final class TransitionRecorder {
    var views: [UIView] = []
    var completions: [() -> Void] = []
}

private struct RecordingTransition: MarkdownStreamingTransition {
    let recorder: TransitionRecorder
    var holds = false

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.recorder === rhs.recorder && lhs.holds == rhs.holds
    }

    func animate(_ view: UIView, completion: @escaping () -> Void) {
        recorder.views.append(view)
        if holds {
            recorder.completions.append(completion)
        } else {
            completion()
        }
    }
}
