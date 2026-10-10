import UIKit
import XCTest
@testable import EnrichedMarkdown

@MainActor
final class CodeBlockAttachmentTests: XCTestCase {
    private let python = "```python\ndef f():\n    return 1 + 2  # note\n```"
    private let code = "def f():\n    return 1 + 2  # note"
    private var config: MarkdownStyleConfiguration!
    private var window: UIWindow?

    override func setUp() {
        super.setUp()
        config = MarkdownStyleConfiguration.baseline()
    }

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    private func render(_ markdown: String, layout: MarkdownCodeBlockLayout = .scrollable) -> NSAttributedString {
        MarkdownRenderer.render(markdown, config: config, codeBlockLayout: layout)
    }

    private func attachments(in rendered: NSAttributedString) -> [CodeBlockAttachment] {
        var found: [CodeBlockAttachment] = []
        rendered.enumerateAttribute(.attachment, in: NSRange(location: 0, length: rendered.length)) { value, _, _ in
            if let code = value as? CodeBlockAttachment { found.append(code) }
        }
        return found
    }

    private func hasCodeBlockAttribute(_ rendered: NSAttributedString) -> Bool {
        var found = false
        rendered.enumerateAttribute(MarkdownAttribute.codeBlock, in: NSRange(location: 0, length: rendered.length)) { value, _, _ in
            if MarkdownAttributeValue.boolValue(from: value) { found = true }
        }
        return found
    }

    // MARK: - Rendering

    func testWrappingIsTheDefault() {
        let rendered = MarkdownRenderer.render(python, config: config)
        XCTAssertTrue(attachments(in: rendered).isEmpty)
        XCTAssertTrue(hasCodeBlockAttribute(rendered))
    }

    func testScrollableRendersOneAttachmentWithoutTheCodeBlockAttribute() {
        let rendered = render("before\n\n\(python)\n\nafter")
        let found = attachments(in: rendered)

        XCTAssertEqual(found.count, 1)
        XCTAssertFalse(hasCodeBlockAttribute(rendered))
        XCTAssertTrue(rendered.string.contains("before"))
        XCTAssertTrue(rendered.string.contains("after"))
        XCTAssertFalse(rendered.string.contains("def f()"))

        let attachment = found[0]
        XCTAssertEqual(attachment.code, code)
        XCTAssertEqual(attachment.language, "python")
        XCTAssertEqual(attachment.displayLanguage, "Python")
        XCTAssertEqual(attachment.fenceCharacter, "`")
        XCTAssertEqual(attachment.attributedCode.string, code)
    }

    func testAttributedCodeCarriesTheBlockFontAndColorOnFixedLines() {
        config = MarkdownStyleConfiguration.resolve(layers: [.default, MarkdownTheme {
            CodeBlock()
                .font(size: 13, design: .monospaced)
                .foregroundStyle(.red)
                .lineHeight(22)
                .padding(10)
        }], traitCollection: UITraitCollection(userInterfaceStyle: .light))
        guard let attachment = attachments(in: render(python)).first else { return XCTFail("no attachment") }

        let attributes = attachment.attributedCode.attributes(at: 0, effectiveRange: nil)
        XCTAssertEqual((attributes[.font] as? UIFont)?.pointSize, 13)
        XCTAssertEqual(attributes[.foregroundColor] as? UIColor, config.codeBlock.foregroundColor)
        let paragraph = attributes[.paragraphStyle] as? NSParagraphStyle
        XCTAssertEqual(paragraph?.minimumLineHeight, 22)
        XCTAssertEqual(paragraph?.maximumLineHeight, 22)
        XCTAssertEqual(paragraph?.lineBreakMode, .byClipping)
        XCTAssertEqual(paragraph?.baseWritingDirection, .leftToRight)

        let layout = attachment.layout
        // A fixed line height carries a baseline offset that shortens each fragment under TextKit 2,
        // so the height is measured, not two times 22.
        XCTAssertLessThanOrEqual(layout.codeSize.height, 44)
        XCTAssertGreaterThanOrEqual(layout.codeSize.height, 2 * attachment.style.font.lineHeight)
        XCTAssertEqual(layout.contentInset, 10 + attachment.style.borderWidth)
        XCTAssertEqual(layout.totalHeight, layout.headerHeight + layout.contentInset * 2 + layout.codeSize.height)
    }

    func testHeaderForegroundStyleTintsTheLabelAndButton() throws {
        config = MarkdownStyleConfiguration.resolve(layers: [.default, MarkdownTheme {
            CodeBlock().headerForegroundStyle(.red)
        }], traitCollection: UITraitCollection(userInterfaceStyle: .light))
        let attachment = try XCTUnwrap(attachments(in: render(python)).first)
        XCTAssertEqual(attachment.style.headerTextColor, config.codeBlock.headerForegroundColor)
        let textView = laidOutTextView(showing: render(python))
        let view = try XCTUnwrap(textView.firstSubview(of: CodeBlockAttachmentView.self))
        XCTAssertEqual(try XCTUnwrap(view.firstSubview(of: UILabel.self)).textColor, config.codeBlock.headerForegroundColor)
        XCTAssertEqual(try XCTUnwrap(view.firstSubview(of: UIButton.self)).tintColor, config.codeBlock.headerForegroundColor)
    }

    func testLongLinesAreNotWrapped() {
        let longLine = String(repeating: "x", count: 400)
        guard let attachment = attachments(in: render("```\n\(longLine)\n```")).first else {
            return XCTFail("no attachment")
        }
        XCTAssertLessThan(attachment.layout.codeSize.height, attachment.style.font.lineHeight * 2)
        XCTAssertGreaterThan(attachment.layout.codeSize.width, 1000)
    }

    /// Without a themed line height a line takes its natural height, so a
    /// fallback-font glyph taller than the code font is not clipped.
    func testNaturalLineHeightsFollowTheTallestGlyph() throws {
        let plain = try XCTUnwrap(attachments(in: render("```\nabc\nabc\n```")).first)
        let emoji = try XCTUnwrap(attachments(in: render("```\nabc\n\u{1F600}\u{1F600}\n```")).first)
        let paragraph = plain.attributedCode.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(paragraph?.maximumLineHeight, 0)
        XCTAssertGreaterThanOrEqual(emoji.layout.codeSize.height, plain.layout.codeSize.height)
    }

    func testEmptyBlockHasNoCodeRowAndNoVoiceOverElement() throws {
        let rendered = render("before\n\n```\n```")
        let attachment = try XCTUnwrap(attachments(in: rendered).first)
        XCTAssertEqual(attachment.code, "")
        XCTAssertEqual(attachment.layout.codeSize.height, 0)
        XCTAssertEqual(attachment.layout.totalHeight, attachment.layout.headerHeight + attachment.layout.contentInset * 2)
        XCTAssertEqual(MarkdownAccessibilityElementBuilder.specs(for: rendered).map(\.label), ["before"])
    }

    func testTrailingBlankLinesAreDropped() {
        XCTAssertEqual(attachments(in: render("```\nx\n\n\n```")).first?.code, "x")
    }

    func testIndentedBlockHasNoLanguageAndRefencesWithBackticks() throws {
        let attachment = try XCTUnwrap(attachments(in: render("para\n\n    let a = 1\n    let b = 2\n")).first)
        XCTAssertNil(attachment.language)
        XCTAssertEqual(attachment.code, "let a = 1\nlet b = 2")
        XCTAssertEqual(attachment.markdownText(), "```\nlet a = 1\nlet b = 2\n```")
    }

    func testBlockInsideABlockquoteKeepsTheQuoteContext() throws {
        let rendered = render("> quote\n>\n> ```js\n> let a = 1;\n> ```")
        let location = (rendered.string as NSString).range(of: "\u{FFFC}").location
        XCTAssertNotEqual(location, NSNotFound)
        let attrs = rendered.attributes(at: location, effectiveRange: nil)
        XCTAssertNotNil(attrs[MarkdownAttribute.blockquoteDepth])
        XCTAssertEqual(attachments(in: rendered).first?.code, "let a = 1;")
    }

    func testUnknownLanguageIsCapitalizedAndMissingLanguageIsNil() {
        XCTAssertEqual(attachments(in: render("```foo\nx\n```")).first?.displayLanguage, "Foo")
        XCTAssertEqual(attachments(in: render("```TSX\nx\n```")).first?.displayLanguage, "TSX")
        XCTAssertEqual(attachments(in: render("```sh\nx\n```")).first?.displayLanguage, "Shell")
        let bare = attachments(in: render("```\nx\n```")).first
        XCTAssertNil(bare?.language)
        XCTAssertNil(bare?.displayLanguage)
    }

    func testBlockInsideAListItemStaysAnAttachment() {
        let rendered = render("- item\n\n  ```js\n  let a = 1;\n  ```\n- next")
        XCTAssertEqual(attachments(in: rendered).first?.code, "let a = 1;")
        XCTAssertTrue(rendered.string.contains("next"))
        // Like a wrapping block, the panel is not the item's text: no marker, no indent.
        let location = (rendered.string as NSString).range(of: "\u{FFFC}").location
        let attrs = rendered.attributes(at: location, effectiveRange: nil)
        XCTAssertNil(attrs[MarkdownAttribute.listItemNumber])
        XCTAssertEqual((attrs[.paragraphStyle] as? NSParagraphStyle)?.headIndent ?? 0, 0)
    }

    // MARK: - Copy

    func testMarkdownTextRestoresTheFence() {
        XCTAssertEqual(attachments(in: render(python)).first?.markdownText(), python)
        XCTAssertEqual(attachments(in: render("~~~\nx\n~~~")).first?.markdownText(), "~~~\nx\n~~~")
        XCTAssertEqual(attachments(in: render("```\n```")).first?.markdownText(), "```\n```")
        XCTAssertEqual(
            attachments(in: render("````md\n```js\nx\n```\n````")).first?.markdownText(),
            "````md\n```js\nx\n```\n````"
        )
    }

    func testCopyAsMarkdownReconstructsTheBlock() {
        let rendered = render("before\n\n\(python)\n\nafter")
        let markdown = MarkdownExtractor.markdown(
            for: NSRange(location: 0, length: rendered.length),
            in: rendered,
            sourceMarkdown: nil
        )
        XCTAssertEqual(markdown?.trimmingCharacters(in: .newlines), "before\n\n\(python)\n\nafter")
    }

    func testPartialSelectionSpanningTheBlockSlicesTheSource() {
        let source = "first line\n\n\(python)\n\nlast line"
        let rendered = render(source)
        let string = rendered.string as NSString
        let start = string.range(of: "line").location
        let end = NSMaxRange(string.range(of: "last"))
        let markdown = MarkdownExtractor.markdown(
            for: NSRange(location: start, length: end - start),
            in: rendered,
            sourceMarkdown: source
        )
        XCTAssertEqual(markdown, "line\n\n\(python)\n\nlast")
    }

    func testPlainTextAndHTMLFlavorsCarryTheCode() {
        let rendered = render("before\n\n```html\n<b>&</b>\n```")
        let full = NSRange(location: 0, length: rendered.length)
        let plain = MarkdownTextView.plainText(of: rendered, in: full)
        XCTAssertTrue(plain.hasPrefix("before\n"), plain)
        XCTAssertTrue(plain.contains("\n<b>&</b>\n"), plain)
        XCTAssertFalse(plain.contains("\u{FFFC}"), plain)

        let html = MarkdownHTMLGenerator.generateHTML(from: rendered, in: full, config: config)
        XCTAssertTrue(html.contains("<pre dir=\"ltr\""), html)
        XCTAssertTrue(html.contains("&lt;b&gt;&amp;&lt;/b&gt;</code></pre>"), html)
    }

    // MARK: - Accessibility

    func testBlockIsOneElementWithTheCopyActionAndLanguage() {
        let specs = MarkdownAccessibilityElementBuilder.specs(for: render("before\n\n\(python)"))
        XCTAssertEqual(specs.count, 2)
        XCTAssertEqual(specs[1].kind, .codeBlock(copyAction: "Copy code", language: "python"))
        XCTAssertEqual(specs[1].label, code)
    }

    func testVoiceOverCopyActionCopiesAndReportsTheLanguage() throws {
        let textView = MarkdownTextView()
        let pasteboard = UIPasteboard.withUniqueName()
        textView.pasteboard = pasteboard
        var copies: [CodeBlockCopy] = []
        textView.onCodeBlockCopy = { copies.append($0) }
        textView.setMarkdownAttributedText(render(python))

        let element = try XCTUnwrap(textView.accessibilityElements?.first as? UIAccessibilityElement)
        let action = try XCTUnwrap(element.accessibilityCustomActions?.first)
        XCTAssertEqual(action.name, "Copy code")
        XCTAssertTrue(action.actionHandler?(action) ?? false)
        XCTAssertEqual(pasteboard.string, code)
        XCTAssertEqual(copies, [CodeBlockCopy(code: code, language: "python")])
    }

    // MARK: - View

    private func laidOutTextView(showing rendered: NSAttributedString) -> MarkdownTextView {
        let textView = MarkdownTextView()
        textView.styleConfig = config
        textView.frame = CGRect(x: 0, y: 0, width: 380, height: 10)
        textView.setMarkdownAttributedText(rendered)

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 380, height: 1000))
        window.addSubview(textView)
        window.makeKeyAndVisible()
        self.window = window
        let fitted = textView.sizeThatFits(CGSize(width: 380, height: CGFloat.greatestFiniteMagnitude))
        textView.frame.size.height = fitted.height
        textView.layoutIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
        textView.layoutIfNeeded()
        return textView
    }

    /// Breaks silently with an undeclared UTI, nil contents, or an
    /// attachment-side viewProvider override.
    func testProviderViewIsInstalledAndSizedToTheLayout() throws {
        let rendered = render("before\n\n\(python)\n\nafter")
        let textView = laidOutTextView(showing: rendered)
        let view = try XCTUnwrap(textView.firstSubview(of: CodeBlockAttachmentView.self))
        let attachment = try XCTUnwrap(attachments(in: rendered).first)

        XCTAssertEqual(view.bounds.width, 380)
        XCTAssertEqual(view.bounds.height, attachment.layout.totalHeight)
        let label = try XCTUnwrap(view.firstSubview(of: UILabel.self))
        XCTAssertEqual(label.text, "Python")
        let scrollView = try XCTUnwrap(view.firstSubview(of: UIScrollView.self))
        XCTAssertFalse(scrollView.isScrollEnabled)
    }

    func testTheSameViewSurvivesALayoutPass() throws {
        let textView = laidOutTextView(showing: render(python))
        let before = try XCTUnwrap(textView.firstSubview(of: CodeBlockAttachmentView.self))
        textView.setNeedsLayout()
        textView.layoutIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
        let after = try XCTUnwrap(textView.firstSubview(of: CodeBlockAttachmentView.self))
        XCTAssertTrue(before === after)
    }

    func testLongPressLiftsADrawnCopyAndHidesThePanel() throws {
        let textView = laidOutTextView(showing: render(python))
        let view = try XCTUnwrap(textView.firstSubview(of: CodeBlockAttachmentView.self))
        let interaction = try XCTUnwrap(view.interactions.compactMap { $0 as? UIContextMenuInteraction }.first)
        let configuration = UIContextMenuConfiguration(identifier: nil, previewProvider: nil, actionProvider: nil)
        let preview = try XCTUnwrap(view.contextMenuInteraction(interaction, previewForHighlightingMenuWithConfiguration: configuration))
        XCTAssertTrue(preview.view is CodeBlockLiftView)
        XCTAssertEqual(preview.view.bounds.size, view.bounds.size)
        XCTAssertNotNil(preview.parameters.visiblePath)

        view.contextMenuInteraction(interaction, willDisplayMenuFor: configuration, animator: nil)
        XCTAssertEqual(view.alpha, 0)
        let image = UIGraphicsImageRenderer(bounds: preview.view.bounds).image { preview.view.layer.render(in: $0.cgContext) }
        XCTAssertNotNil(image.cgImage)

        view.removeFromSuperview()
        XCTAssertNil(view.contextMenuInteraction(interaction, previewForDismissingMenuWithConfiguration: configuration))
    }

    func testWideCodeScrollsSideways() throws {
        let longLine = String(repeating: "x", count: 400)
        let textView = laidOutTextView(showing: render("```\n\(longLine)\n```"))
        let view = try XCTUnwrap(textView.firstSubview(of: CodeBlockAttachmentView.self))
        let scrollView = try XCTUnwrap(view.firstSubview(of: UIScrollView.self))
        XCTAssertTrue(scrollView.isScrollEnabled)
        XCTAssertGreaterThan(scrollView.contentSize.width, scrollView.bounds.width)
    }

    /// A long block draws a tile around the visible region that follows the
    /// enclosing scroll view, not a bitmap its own height.
    func testLongBlockDrawsATileThatFollowsTheScrollView() throws {
        let code = (1...400).map { "line \($0)" }.joined(separator: "\n")
        let rendered = render("```\n\(code)\n```")
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let scrollView = UIScrollView(frame: window.bounds)
        window.addSubview(scrollView)
        window.makeKeyAndVisible()
        self.window = window
        let textView = MarkdownTextView()
        textView.styleConfig = config
        textView.frame = CGRect(x: 0, y: 0, width: 390, height: 10)
        textView.setMarkdownAttributedText(rendered)
        scrollView.addSubview(textView)
        let height = textView.sizeThatFits(CGSize(width: 390, height: CGFloat.greatestFiniteMagnitude)).height
        textView.frame.size.height = height
        scrollView.contentSize = CGSize(width: 390, height: height)
        textView.layoutIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))

        let view = try XCTUnwrap(textView.firstSubview(of: CodeBlockAttachmentView.self))
        let pane = try XCTUnwrap(view.firstSubview(of: CodeBlockContentView.self))
        let attachment = try XCTUnwrap(attachments(in: rendered).first)
        XCTAssertGreaterThan(attachment.layout.codeSize.height, 4000)
        XCTAssertLessThanOrEqual(pane.frame.height, 844 + CodeBlockAttachmentView.tileMargin * 2)
        XCTAssertEqual(pane.frame.minY, attachment.layout.contentInset)
        XCTAssertEqual(pane.bounds.origin, .zero)

        scrollView.contentOffset = CGPoint(x: 0, y: 3000)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertGreaterThan(pane.frame.minY, 1000)
        XCTAssertEqual(pane.bounds.origin.y, pane.frame.minY - attachment.layout.contentInset)
    }

    func testScrollOffsetSurvivesARerender() throws {
        let longLine = String(repeating: "x", count: 400)
        let textView = laidOutTextView(showing: render("```\n\(longLine)\n```"))
        let view = try XCTUnwrap(textView.firstSubview(of: CodeBlockAttachmentView.self))
        let scrollView = try XCTUnwrap(view.firstSubview(of: UIScrollView.self))
        scrollView.contentOffset = CGPoint(x: 120, y: 0)
        scrollView.delegate?.scrollViewDidScroll?(scrollView)

        let rerendered = render("```\n\(longLine)\n```")
        textView.setMarkdownAttributedText(rerendered)
        XCTAssertEqual(attachments(in: rerendered).first?.preservedContentOffset.x, 120)
    }

    func testOutwardPanYieldsOnlyWhenSettledAtTheLeadingEdge() {
        let yield = HorizontalBlockScrollView.shouldYieldOutwardPan
        XCTAssertTrue(yield(0, 0, false, CGPoint(x: 10, y: 2)))
        XCTAssertFalse(yield(0, 0, false, CGPoint(x: -10, y: 2)))
        XCTAssertFalse(yield(0, 0, false, CGPoint(x: 3, y: 10)))
        XCTAssertFalse(yield(40, 0, false, CGPoint(x: 10, y: 0)))
        XCTAssertFalse(yield(0, 0, true, CGPoint(x: 10, y: 0)))
    }

    func testCopyButtonCopiesThroughTheHostTextView() throws {
        let textView = laidOutTextView(showing: render(python))
        let pasteboard = UIPasteboard.withUniqueName()
        textView.pasteboard = pasteboard
        var copies: [CodeBlockCopy] = []
        textView.onCodeBlockCopy = { copies.append($0) }

        let view = try XCTUnwrap(textView.firstSubview(of: CodeBlockAttachmentView.self))
        XCTAssertTrue(view.enclosingMarkdownTextView() === textView)
        let button = try XCTUnwrap(view.firstSubview(of: UIButton.self))
        let action = try XCTUnwrap(button.actions(forTarget: view, forControlEvent: .touchUpInside)?.first)
        _ = view.perform(NSSelectorFromString(action))

        XCTAssertEqual(pasteboard.string, code)
        XCTAssertEqual(copies, [CodeBlockCopy(code: code, language: "python")])
    }
}
