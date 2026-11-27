import UIKit
import XCTest
@testable import EnrichedMarkdown
@testable import EnrichedMarkdownSyntaxHighlighting

final class SyntaxHighlightingCopyTests: XCTestCase {
    private let source = """
    Intro text.

    ```python
    def f(a, b):
        x = 1

        return "s"  # note
    ```

    - item

      ```js
      let a = 1;
      ```

    Outro.
    """

    private var config: MarkdownStyleConfiguration!
    private var plain: NSAttributedString!
    private var highlighted: NSAttributedString!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        config = highlightingConfig()
        plain = MarkdownRenderer.render(source, config: config)
        highlighted = MarkdownRenderer.renderSyntaxHighlighted(source, config: config)
    }

    private func assertSameOutput(
        _ output: (NSAttributedString, NSRange) -> String?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for location in 0..<plain.length {
            for length in 1...(plain.length - location) {
                let range = NSRange(location: location, length: length)
                XCTAssertEqual(output(highlighted, range), output(plain, range), "\(range)", file: file, line: line)
            }
        }
    }

    func testFixtureHighlightsWithoutChangingTheText() {
        XCTAssertEqual(highlighted.string, plain.string)
        XCTAssertNotEqual(highlighted, plain)
    }

    func testCopyAsMarkdownMatchesThePlainRender() {
        assertSameOutput { text, range in
            MarkdownExtractor.markdown(for: range, in: text, sourceMarkdown: self.source)
        }
    }

    func testReconstructedMarkdownMatchesThePlainRender() {
        assertSameOutput { text, range in
            MarkdownExtractor.extractMarkdown(from: text, in: range)
        }
    }

    func testReconstructedMarkdownClosesTheFence() {
        let full = NSRange(location: 0, length: highlighted.length)
        let markdown = MarkdownExtractor.extractMarkdown(from: highlighted, in: full)

        XCTAssertEqual(markdown?.components(separatedBy: "```").count, 5, "two blocks, each opened and closed")
    }

    func testCopiedHTMLMatchesThePlainRender() {
        assertSameOutput { text, range in
            MarkdownHTMLGenerator.generateHTML(from: text, in: range, config: self.config)
        }
    }
}
