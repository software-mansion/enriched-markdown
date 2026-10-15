import UIKit
import XCTest
@testable import EnrichedMarkdown

final class OrderedListMarkerWidthTests: XCTestCase {
    private var config: MarkdownStyleConfiguration!

    override func setUp() {
        super.setUp()
        config = MarkdownStyleConfiguration.baseline()
    }

    func testShortListsKeepTheirMarkerColumn() {
        let result = MarkdownRenderer.render(numbered(9), config: config)

        // Default theme: 20pt ordered marker column + 12pt gap.
        XCTAssertEqual(headIndent(in: result, at: "i1x"), 32)
        XCTAssertEqual(headIndent(in: result, at: "i9x"), 32)
    }

    func testListsWidenTheirColumnToTheirWidestNumber() {
        for count in [12, 99, 101, 1000] {
            let result = MarkdownRenderer.render(numbered(count), config: config)
            let widest = (1...count).map { markerWidth("\($0).") }.max() ?? 0
            XCTAssertGreaterThan(widest, 20, "list of \(count)")

            for item in ["i1x", "i\(count)x"] {
                XCTAssertEqual(headIndent(in: result, at: item), widest + 12, accuracy: 0.001, "\(item) of \(count)")
            }
        }
    }

    func testMarkerMinWidthRemainsAFloor() {
        config.list.markerMinWidth = 200
        let result = MarkdownRenderer.render(numbered(1000), config: config)

        XCTAssertEqual(headIndent(in: result, at: "i1x"), 212)
        XCTAssertEqual(headIndent(in: result, at: "i1000x"), 212)
    }

    func testFollowingListsRestoreTheirOwnColumn() {
        let result = MarkdownRenderer.render(numbered(101) + "\nbreak\n\n" + numbered(3, prefix: "f"), config: config)

        XCTAssertGreaterThan(headIndent(in: result, at: "i101x"), 32)
        XCTAssertEqual(headIndent(in: result, at: "f1x"), 32)
    }

    func testNestedListsKeepTheirPlaceUnderWideParents() {
        for nested in ["- nestedx", "1. nestedx", "- [ ] nestedx"] {
            let short = nestedOffset(in: numbered(4, nesting: nested, under: 3), parent: "i3x")
            for count in [101, 1000] {
                let wide = nestedOffset(in: numbered(count, nesting: nested, under: 3), parent: "i3x")
                XCTAssertEqual(wide, short, accuracy: 0.001, "\(nested) under a list of \(count)")
            }
        }
    }

    func testListsInsideAQuoteUnderAWideParentShiftOnce() {
        func offset(_ count: Int) -> CGFloat {
            let source = numbered(count, nesting: "> quotex\n>\n> - nestedx", under: 3)
            let result = MarkdownRenderer.render(source, config: config)
            return headIndent(in: result, at: "nestedx") - headIndent(in: result, at: "quotex")
        }

        for count in [101, 1000] {
            XCTAssertEqual(offset(count), offset(4), accuracy: 0.001, "list of \(count)")
        }
    }

    func testQuotesUnderSeveralListLevelsShiftOnce() {
        func offsets(_ count: Int) -> (text: CGFloat, bar: CGFloat) {
            let source = numbered(count, nesting: "- childx\n  > quotex", under: 3)
            let result = MarkdownRenderer.render(source, config: config)
            let quote = (result.string as NSString).range(of: "quotex").location
            let bar = result.attribute(MarkdownAttribute.blockquoteBarOffset, at: quote, effectiveRange: nil)
            let barOffset = bar as? CGFloat ?? -1
            return (headIndent(in: result, at: "quotex") - headIndent(in: result, at: "childx"),
                    headIndent(in: result, at: "quotex") - barOffset)
        }

        let short = offsets(4)
        for count in [101, 1000] {
            let wide = offsets(count)
            XCTAssertEqual(wide.text, short.text, accuracy: 0.001, "quote under a list of \(count)")
            XCTAssertEqual(wide.bar, short.bar, accuracy: 0.001, "quote bar under a list of \(count)")
        }
    }

    func testQuoteBarsKeepTheWideningOfAnInnerList() {
        func offsets(_ count: Int) -> (text: CGFloat, bar: CGFloat) {
            let inner = numbered(count, prefix: "n", nesting: "> quotex", under: 3)
            let result = MarkdownRenderer.render(numbered(4, nesting: inner, under: 2), config: config)
            let quote = (result.string as NSString).range(of: "quotex").location
            let bar = result.attribute(MarkdownAttribute.blockquoteBarOffset, at: quote, effectiveRange: nil)
            let barOffset = bar as? CGFloat ?? -1
            return (headIndent(in: result, at: "quotex") - headIndent(in: result, at: "n3x"),
                    headIndent(in: result, at: "quotex") - barOffset)
        }

        let short = offsets(4)
        for count in [101, 1000] {
            let wide = offsets(count)
            XCTAssertEqual(wide.text, short.text, accuracy: 0.001, "quote in a nested list of \(count)")
            XCTAssertEqual(wide.bar, short.bar, accuracy: 0.001, "quote bar in a nested list of \(count)")
        }
    }

    func testWideListsInsideAQuoteKeepTheQuoteBarInPlace() {
        func barOffset(_ result: NSAttributedString, at text: String) -> CGFloat {
            let location = (result.string as NSString).range(of: text).location
            return result.attribute(MarkdownAttribute.blockquoteBarOffset, at: location, effectiveRange: nil) as? CGFloat ?? -1
        }

        for count in [4, 101, 1000] {
            let inner = numbered(count, prefix: "n", nesting: "> innerx", under: 3)
            let quote = "> beforex\n>\n" + inner.split(separator: "\n").map { "> " + $0 }.joined(separator: "\n")
                + "\n>\n> afterx"
            let result = MarkdownRenderer.render(numbered(4, nesting: quote, under: 1), config: config)
            XCTAssertEqual(barOffset(result, at: "innerx"), barOffset(result, at: "beforex"), "list of \(count)")
            XCTAssertEqual(barOffset(result, at: "afterx"), barOffset(result, at: "beforex"), "list of \(count)")
        }
    }

    func testTaskChildrenMoveOnlyAsFarAsTheirCheckboxColumn() {
        for checkboxSize: CGFloat in [22, 100] {
            config.taskList.checkboxSize = checkboxSize
            func offset(_ count: Int) -> CGFloat {
                var lines = (1...count).map { "\($0). i\($0)x" }
                lines[1] = "2. [ ] taskx\n   - childx"
                let result = MarkdownRenderer.render(lines.joined(separator: "\n"), config: config)
                return headIndent(in: result, at: "childx") - headIndent(in: result, at: "taskx")
            }

            for count in [101, 1000] {
                XCTAssertEqual(offset(count), offset(4), accuracy: 0.001, "checkbox \(checkboxSize), list of \(count)")
            }
        }
    }

    func testNestedWideListsWidenOnlyThemselves() {
        let source = numbered(3, nesting: numbered(101, prefix: "n"), under: 2)
        let result = MarkdownRenderer.render(source, config: config)
        let nestedWidest = (1...101).map { markerWidth("\($0).") }.max() ?? 0

        XCTAssertEqual(headIndent(in: result, at: "i1x"), 32)
        XCTAssertEqual(headIndent(in: result, at: "n101x"), 32 + 24 - 20 + nestedWidest, accuracy: 0.001)
    }

    func testTaskItemsAlignWithWideNumberedSiblings() {
        let source = (1...101).map { $0 == 2 ? "2. [ ] taskx" : "\($0). i\($0)x" }.joined(separator: "\n")
        let result = MarkdownRenderer.render(source, config: config)

        XCTAssertEqual(headIndent(in: result, at: "taskx"), headIndent(in: result, at: "i1x"))
    }

    func testTaskItemChildrenFollowTheirWideNumberedSiblings() {
        var lines = (1...101).map { "\($0). i\($0)x" }
        lines[1] = "2. [ ] taskx\n   - undertaskx"
        lines[2] = "3. i3x\n   - undernumberx"
        let result = MarkdownRenderer.render(lines.joined(separator: "\n"), config: config)

        XCTAssertEqual(
            headIndent(in: result, at: "undertaskx") - headIndent(in: result, at: "taskx"),
            headIndent(in: result, at: "undernumberx") - headIndent(in: result, at: "i3x"),
            accuracy: 0.001
        )
    }

    private func nestedOffset(in source: String, parent: String) -> CGFloat {
        let result = MarkdownRenderer.render(source, config: config)
        return headIndent(in: result, at: "nestedx") - headIndent(in: result, at: parent)
    }

    /// An ordered list of `count` items `<prefix><n>x`, with `nesting` under item `under`.
    private func numbered(_ count: Int, prefix: String = "i", nesting: String? = nil, under: Int = 0) -> String {
        (1...count).map { number in
            var item = "\(number). \(prefix)\(number)x"
            if let nesting, number == under {
                let indent = String(repeating: " ", count: "\(number). ".count)
                item += "\n" + nesting.split(separator: "\n").map { indent + $0 }.joined(separator: "\n")
            }
            return item
        }.joined(separator: "\n") + "\n"
    }

    private func markerWidth(_ marker: String) -> CGFloat {
        let font = config.list.font ?? BlockDecorationConfig.defaultListMarkerFont
        return (marker as NSString).size(withAttributes: [.font: font]).width
    }

    private func headIndent(in result: NSAttributedString, at substring: String) -> CGFloat {
        let range = (result.string as NSString).range(of: substring)
        XCTAssertNotEqual(range.location, NSNotFound, substring)
        guard range.location != NSNotFound else { return -1 }
        let style = result.attribute(.paragraphStyle, at: range.location, effectiveRange: nil) as? NSParagraphStyle
        return style?.headIndent ?? -1
    }
}
