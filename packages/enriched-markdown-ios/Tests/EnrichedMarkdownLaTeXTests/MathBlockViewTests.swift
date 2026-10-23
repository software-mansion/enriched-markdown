import UIKit
import XCTest
@testable import EnrichedMarkdown
@testable import EnrichedMarkdownLaTeX

@MainActor
final class MathBlockViewTests: XCTestCase {
    // MARK: - Helpers

    private func blockAttachment(
        padding: CGFloat = 12,
        alignment: NSTextAlignment = .center,
        background: UIColor? = nil
    ) -> MathAttachment {
        MathAttachment(
            latex: "x",
            isDisplay: true,
            result: stubResult(),
            panel: MathPanelStyle(backgroundColor: background, padding: padding, textAlignment: alignment),
            accessibilityLabel: "Math: x"
        )
    }

    /// A laid-out block view `width` points wide for the stub formula
    /// (40 × 16, so 64 wide with the default padding).
    private func layoutView(_ attachment: MathAttachment, width: CGFloat) -> MathBlockView {
        let view = MathBlockView(attachment: attachment, panel: attachment.panel ?? MathPanelStyle())
        view.frame = CGRect(x: 0, y: 0, width: width, height: 40)
        view.layoutIfNeeded()
        return view
    }

    // MARK: - Attachment

    func testOnlyBlockMathDeclaresTheProviderFileType() {
        XCTAssertEqual(blockAttachment().fileType, MathAttachment.fileType)
        XCTAssertNil(
            MathAttachment(latex: "x", isDisplay: false, result: stubResult(), accessibilityLabel: "Math: x").fileType
        )
    }

    // MARK: - Layout

    func testFittingFormulaIsAlignedAndDoesNotScroll() {
        let view = layoutView(blockAttachment(alignment: .center, background: .systemRed), width: 300)

        XCTAssertFalse(view.scrollView.isScrollEnabled)
        XCTAssertEqual(view.scrollView.contentSize, CGSize(width: 300, height: 40))
        XCTAssertEqual(view.formulaView.frame, CGRect(x: 130, y: 12, width: 40, height: 16))
        XCTAssertEqual(view.backgroundColor, .systemRed)
    }

    func testOverflowingFormulaScrollsHorizontally() {
        let view = layoutView(blockAttachment(alignment: .center), width: 50)

        XCTAssertTrue(view.scrollView.isScrollEnabled)
        XCTAssertEqual(view.scrollView.contentSize, CGSize(width: 64, height: 40))
        XCTAssertEqual(view.formulaView.frame.origin, CGPoint(x: 12, y: 12), "starts at the inset")
    }

    func testUpdatedBlockKeepsItsScrollOffset() {
        let view = layoutView(blockAttachment(), width: 50)
        view.scrollView.contentOffset = CGPoint(x: 10, y: 0)

        view.update(to: blockAttachment(background: .systemRed))
        view.layoutIfNeeded()
        XCTAssertEqual(view.scrollView.contentOffset.x, 10)
        XCTAssertEqual(view.backgroundColor, .systemRed)
        XCTAssertEqual(view.formulaView.frame.origin, CGPoint(x: 12, y: 12))
    }

    // MARK: - Text view integration

    /// Breaks silently with an undeclared UTI, nil contents, or an
    /// attachment-side viewProvider override. The formula is wider than the
    /// text view, so the block must stay line-wide rather than widen with it.
    func testProviderViewIsInstalledInTextView() {
        let config = MarkdownStyleConfiguration.baseline()
        let wide = MathTypesetResult(width: 1000, ascent: 12, descent: 4) { _ in }
        let rendered = MarkdownRenderer.render(
            "before\n\n$$E=mc^2$$\n\nafter",
            config: config,
            options: .commonMark,
            imageRequestHeaders: [:],
            plugins: [LaTeXRenderPlugin(typeset: { _, _, _, _ in wide })]
        )

        let (window, textView) = hostedTextView(config: config)
        defer { window.isHidden = true }
        textView.setMarkdownAttributedText(rendered)
        settle(textView)

        let blockView = textView.firstSubview(of: MathBlockView.self)
        XCTAssertNotNil(blockView)
        XCTAssertEqual(blockView?.bounds.width, textView.textContainer.size.width - textView.textContainer.lineFragmentPadding * 2)
    }
}
