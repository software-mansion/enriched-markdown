import UIKit
import XCTest
@testable import EnrichedMarkdown

private struct RecordStyle: PluginStyle {
    var size: CGFloat?
    var name: String?

    mutating func merge(_ other: RecordStyle) {
        size = other.size ?? size
        name = other.name ?? name
    }
}

private struct FlagStyle: PluginStyle {
    var enabled: Bool?

    mutating func merge(_ other: FlagStyle) {
        enabled = other.enabled ?? enabled
    }
}

/// Renders the node as a placeholder character; the margin tests only
/// read the paragraph style around it.
private final class PlaceholderRenderer: NodeRenderer {
    func render(node: MarkdownASTNode, into output: NSMutableAttributedString, context: RenderContext) {
        output.append(NSAttributedString(string: "\u{FFFC}", attributes: context.getTextAttributes()))
    }
}

/// Claims display math as a root block with `margins`.
private struct BlockMarginsPlugin: MarkdownRenderPlugin {
    let margins: BlockMargins

    func renderer(for type: NodeType, config: MarkdownStyleConfig) -> NodeRenderer? {
        type == .latexMathDisplay ? PlaceholderRenderer() : nil
    }

    func adjustFlags(_ flags: inout Md4cFlags) {
        flags.latexMathEnabled = true
    }

    var rootBlockNodeTypes: Set<NodeType> { [.latexMathDisplay] }

    func blockMargins(for type: NodeType, config: MarkdownStyleConfig) -> BlockMargins { margins }
}

final class PluginStyleTests: XCTestCase {
    // MARK: - Storage

    func testSubscriptStoresRecordsByType() {
        var storage = PluginStyleStorage()
        XCTAssertNil(storage[RecordStyle.self])

        storage[RecordStyle.self] = RecordStyle(size: 3, name: "a")
        storage[FlagStyle.self] = FlagStyle(enabled: true)

        XCTAssertEqual(storage[RecordStyle.self], RecordStyle(size: 3, name: "a"))
        XCTAssertEqual(storage[FlagStyle.self], FlagStyle(enabled: true))

        storage[FlagStyle.self] = nil
        XCTAssertNil(storage[FlagStyle.self])
        XCTAssertNotNil(storage[RecordStyle.self])
    }

    func testEqualityComparesRecords() {
        var lhs = PluginStyleStorage()
        var rhs = PluginStyleStorage()
        XCTAssertEqual(lhs, rhs)

        lhs[RecordStyle.self] = RecordStyle(size: 3)
        XCTAssertNotEqual(lhs, rhs)

        rhs[RecordStyle.self] = RecordStyle(size: 3)
        XCTAssertEqual(lhs, rhs)

        rhs[RecordStyle.self] = RecordStyle(size: 4)
        XCTAssertNotEqual(lhs, rhs)

        rhs[RecordStyle.self] = RecordStyle(size: 3)
        rhs[FlagStyle.self] = FlagStyle()
        XCTAssertNotEqual(lhs, rhs)
    }

    func testMergeOverlaysSetPropertiesOnly() {
        var base = PluginStyleStorage()
        base[RecordStyle.self] = RecordStyle(size: 3, name: "a")

        var overlay = PluginStyleStorage()
        overlay[RecordStyle.self] = RecordStyle(size: 5)
        overlay[FlagStyle.self] = FlagStyle(enabled: false)

        base.merge(overlay)

        XCTAssertEqual(base[RecordStyle.self], RecordStyle(size: 5, name: "a"))
        XCTAssertEqual(base[FlagStyle.self], FlagStyle(enabled: false))
    }

    func testConfigEqualityAndMergeCoverPluginStyles() {
        var lhs = MarkdownStyleConfig.baseline()
        let rhs = MarkdownStyleConfig.baseline()
        XCTAssertEqual(lhs, rhs)

        lhs.pluginStyles[RecordStyle.self] = RecordStyle(size: 3)
        XCTAssertNotEqual(lhs, rhs)

        var merged = rhs
        merged.merge(lhs)
        XCTAssertEqual(merged.pluginStyles[RecordStyle.self], RecordStyle(size: 3))
    }

    // MARK: - Block margins

    private func render(_ markdown: String, config: MarkdownStyleConfig, margins: BlockMargins) -> NSAttributedString {
        MarkdownRenderer.render(
            markdown,
            config: config,
            flags: .commonMark,
            imageRequestHeaders: [:],
            plugins: [BlockMarginsPlugin(margins: margins)]
        )
    }

    /// `paragraphSpacingBefore` of the spacer line ahead of the block and
    /// `paragraphSpacing` of the block itself.
    private func blockSpacing(in rendered: NSAttributedString) -> (before: CGFloat?, after: CGFloat?) {
        let index = (rendered.string as NSString).range(of: "\u{FFFC}").location
        guard index != NSNotFound, index > 0 else {
            XCTFail("block attachment not rendered")
            return (nil, nil)
        }
        let before = rendered.attribute(.paragraphStyle, at: index - 1, effectiveRange: nil) as? NSParagraphStyle
        let block = rendered.attribute(.paragraphStyle, at: index, effectiveRange: nil) as? NSParagraphStyle
        return (before?.paragraphSpacingBefore, block?.paragraphSpacing)
    }

    private var marginConfig: MarkdownStyleConfig {
        var config = MarkdownStyleConfig.baseline()
        config.paragraph.marginTop = 3
        config.paragraph.marginBottom = 5
        return config
    }

    private let source = "before\n\n$$x$$\n\nafter"

    func testPluginBlockMarginsReplaceParagraphMargins() {
        let rendered = render(source, config: marginConfig, margins: BlockMargins(marginTop: 7, marginBottom: 9))

        let spacing = blockSpacing(in: rendered)
        XCTAssertEqual(spacing.before, 7)
        XCTAssertEqual(spacing.after, 9)
    }

    func testUnsetPluginBlockMarginsFallBackToParagraph() {
        let partial = blockSpacing(in: render(source, config: marginConfig, margins: BlockMargins(marginBottom: 9)))
        XCTAssertEqual(partial.before, 3)
        XCTAssertEqual(partial.after, 9)

        let none = blockSpacing(in: render(source, config: marginConfig, margins: BlockMargins()))
        XCTAssertEqual(none.before, 3)
        XCTAssertEqual(none.after, 5)
    }
}
