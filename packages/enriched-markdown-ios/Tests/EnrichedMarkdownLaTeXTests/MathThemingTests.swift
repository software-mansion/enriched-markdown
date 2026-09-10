import SwiftUI
import UIKit
import XCTest
@testable import EnrichedMarkdown
@testable import EnrichedMarkdownLaTeX

final class MathThemingTests: XCTestCase {
    /// Typeset inputs captured from the last `render`.
    private struct TypesetCall: Equatable {
        var fontSize: CGFloat
        var color: UIColor
    }

    private var typesetCalls: [TypesetCall] = []

    override func setUp() {
        super.setUp()
        typesetCalls = []
    }

    // MARK: - Helpers

    private func config(@MarkdownThemeBuilder _ content: () -> MarkdownThemeGroup) -> MarkdownStyleConfig {
        MarkdownStyleConfig.resolve(layers: [.default, MarkdownTheme(content)], traitCollection: .current)
    }

    private func render(_ markdown: String, config: MarkdownStyleConfig, typesets: Bool = true) -> NSAttributedString {
        MarkdownRenderer.render(
            markdown,
            config: config,
            flags: .commonMark,
            imageRequestHeaders: [:],
            plugins: [LaTeXRenderPlugin(typeset: { _, _, fontSize, color in
                self.typesetCalls.append(TypesetCall(fontSize: fontSize, color: color))
                return typesets ? self.stubResult() : nil
            })]
        )
    }

    private func paragraphFontSize(in config: MarkdownStyleConfig) -> CGFloat {
        (config.paragraph.font ?? UIFont.preferredFont(forTextStyle: .body)).pointSize
    }

    private func bounds(of attachment: MathAttachment, lineWidth: CGFloat) -> CGRect {
        attachment.attachmentBounds(
            for: nil,
            proposedLineFragment: CGRect(x: 0, y: 0, width: lineWidth, height: 20),
            glyphPosition: .zero,
            characterIndex: 0
        )
    }

    // MARK: - Theme elements

    func testMathBlockThemeElementAppliesToConfig() {
        var config = MarkdownStyleConfig()
        MathBlock()
            .fontSize(24)
            .foregroundStyle(Color(UIColor.systemRed))
            .background(Color(UIColor.systemBlue))
            .padding(10)
            .marginTop(4)
            .marginBottom(20)
            .textAlignment(.trailing)
            .apply(to: &config, traitCollection: .current)

        XCTAssertEqual(config.mathBlock.fontSize, 24)
        XCTAssertNotNil(config.mathBlock.foregroundColor)
        XCTAssertNotNil(config.mathBlock.backgroundColor)
        XCTAssertEqual(config.mathBlock.padding, 10)
        XCTAssertEqual(config.mathBlock.marginTop, 4)
        XCTAssertEqual(config.mathBlock.marginBottom, 20)
        XCTAssertEqual(config.mathBlock.textAlignment, .right)
    }

    func testInlineMathThemeElementAppliesToConfig() {
        var config = MarkdownStyleConfig()
        XCTAssertNil(config.inlineMath.foregroundColor)

        InlineMath().foregroundStyle(.tint).apply(to: &config, traitCollection: .current)
        XCTAssertNotNil(config.inlineMath.foregroundColor)
    }

    func testLatexDefaultMatchesReactNativeDefaults() {
        let config = MarkdownStyleConfig.resolve(layers: [.default, .latexDefault], traitCollection: .current)

        XCTAssertEqual(config.mathBlock.fontSize, 20)
        XCTAssertNil(config.mathBlock.foregroundColor, "block color inherits the paragraph's")
        XCTAssertNotNil(config.mathBlock.backgroundColor)
        XCTAssertEqual(config.mathBlock.padding, 12)
        XCTAssertNil(config.mathBlock.marginTop)
        XCTAssertEqual(config.mathBlock.marginBottom, 16)
        XCTAssertEqual(config.mathBlock.textAlignment, .center)
        XCTAssertNil(config.inlineMath.foregroundColor)
    }

    func testLaterThemeLayersOverrideOnlySetMathProperties() {
        let config = MarkdownStyleConfig.resolve(
            layers: [.default, .latexDefault, MarkdownTheme { MathBlock().padding(4).textAlignment(.leading) }],
            traitCollection: .current
        )

        XCTAssertEqual(config.mathBlock.fontSize, 20)
        XCTAssertEqual(config.mathBlock.padding, 4)
        XCTAssertEqual(config.mathBlock.textAlignment, .left)
        XCTAssertEqual(config.mathBlock.marginBottom, 16)
    }

    // MARK: - Rendering

    func testBlockMathTypesetsWithBlockStyle() {
        let config = config {
            MathBlock().fontSize(24).foregroundStyle(Color(UIColor.systemRed)).background(.quaternary).padding(6)
        }
        let rendered = render("$$E=mc^2$$", config: config)

        XCTAssertEqual(typesetCalls, [TypesetCall(fontSize: 24, color: config.mathBlock.foregroundColor!)])
        let attachment = mathAttachments(in: rendered).first
        XCTAssertEqual(attachment?.isBlock, true)
        XCTAssertEqual(attachment?.panel?.padding, 6)
        XCTAssertEqual(attachment?.panel?.backgroundColor, config.mathBlock.backgroundColor)
    }

    func testBlockMathWithoutThemeInheritsParagraph() {
        let config = MarkdownStyleConfig.baseline()
        let rendered = render("$$E=mc^2$$", config: config)

        XCTAssertEqual(typesetCalls, [TypesetCall(fontSize: paragraphFontSize(in: config), color: config.paragraph.foregroundColor!)])
        XCTAssertEqual(mathAttachments(in: rendered).first?.panel, MathPanelStyle())
    }

    func testInlineMathKeepsParagraphSizeAndUsesInlineColor() {
        let config = config {
            MathBlock().fontSize(24).foregroundStyle(Color(UIColor.systemRed))
            InlineMath().foregroundStyle(Color(UIColor.systemBlue))
        }
        let rendered = render("a $x$ and $$y$$ b", config: config)

        let expected = TypesetCall(fontSize: paragraphFontSize(in: config), color: config.inlineMath.foregroundColor!)
        XCTAssertEqual(typesetCalls, [expected, expected])
        XCTAssertNil(mathAttachments(in: rendered).first?.panel, "display math inside a paragraph is not a block")
    }

    func testBlockMathMarginsComeFromTheme() {
        var config = config { MathBlock().marginTop(7).marginBottom(9) }
        config.paragraph.marginTop = 3
        config.paragraph.marginBottom = 5
        let rendered = render("before\n\n$$x$$\n\nafter", config: config)

        let index = (rendered.string as NSString).range(of: "\u{FFFC}").location
        let before = rendered.attribute(.paragraphStyle, at: index - 1, effectiveRange: nil) as? NSParagraphStyle
        let block = rendered.attribute(.paragraphStyle, at: index, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(before?.paragraphSpacingBefore, 7)
        XCTAssertEqual(block?.paragraphSpacing, 9)
    }

    func testTypesetFailureInBlockUsesBlockStyle() {
        let config = config { MathBlock().fontSize(24).foregroundStyle(Color(UIColor.systemRed)) }
        let rendered = render("$$\\frac{1}{$$", config: config, typesets: false)

        let index = (rendered.string as NSString).range(of: "$$").location
        XCTAssertEqual((rendered.attribute(.font, at: index, effectiveRange: nil) as? UIFont)?.pointSize, 24)
        XCTAssertEqual(rendered.attribute(.foregroundColor, at: index, effectiveRange: nil) as? UIColor, config.mathBlock.foregroundColor)
    }

    // MARK: - Panel attachment

    func testPanelAttachmentSpansLineAndInsetsFormula() {
        let attachment = MathAttachment(
            latex: "x",
            isDisplay: true,
            result: stubResult(),
            panel: MathPanelStyle(padding: 12, textAlignment: .center)
        )

        XCTAssertEqual(bounds(of: attachment, lineWidth: 300), CGRect(x: 0, y: -16, width: 300, height: 40))
        XCTAssertEqual(bounds(of: attachment, lineWidth: 50).width, 64, "a wide formula keeps its padded width")
    }

    func testPanelAlignsFormulaInsideInsets() {
        func originX(_ alignment: NSTextAlignment, panelWidth: CGFloat = 300) -> CGFloat {
            MathPanelStyle(padding: 12, textAlignment: alignment).contentOriginX(formulaWidth: 40, panelWidth: panelWidth)
        }

        XCTAssertEqual(originX(.left), 12)
        XCTAssertEqual(originX(.natural), 12)
        XCTAssertEqual(originX(.center), 130)
        XCTAssertEqual(originX(.right), 248)
        XCTAssertEqual(originX(.center, panelWidth: 50), 12, "an overflowing formula starts at the inset")
    }

    func testPanelImageFillsBackgroundAndRerendersPerSize() {
        func image(background: UIColor?, width: CGFloat) -> UIImage? {
            let attachment = MathAttachment(
                latex: "x",
                isDisplay: true,
                result: stubResult(),
                panel: MathPanelStyle(backgroundColor: background, padding: 12)
            )
            let size = CGSize(width: width, height: 40)
            return attachment.image(forBounds: CGRect(origin: .zero, size: size), textContainer: nil, characterIndex: 0)
        }

        XCTAssertEqual(image(background: nil, width: 300).map(isBlank), true)
        XCTAssertEqual(image(background: .systemRed, width: 300).map(isBlank), false)

        let attachment = MathAttachment(latex: "x", isDisplay: true, result: stubResult(), panel: MathPanelStyle())
        let narrow = attachment.image(forBounds: CGRect(x: 0, y: 0, width: 100, height: 16), textContainer: nil, characterIndex: 0)
        let wide = attachment.image(forBounds: CGRect(x: 0, y: 0, width: 200, height: 16), textContainer: nil, characterIndex: 0)
        XCTAssertEqual(narrow?.size.width, 100)
        XCTAssertEqual(wide?.size.width, 200)
    }
}
