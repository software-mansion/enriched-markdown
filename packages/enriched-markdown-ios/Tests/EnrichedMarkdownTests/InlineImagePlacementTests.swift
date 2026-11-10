import UIKit
import XCTest
@testable import EnrichedMarkdown

/// Inline images fit inside their square (contain) and centre on the text's cap height.
@MainActor
final class InlineImagePlacementTests: XCTestCase {
    func testAnInlineImageIsCentredOnTheCapHeight() throws {
        let cases: [(markdown: String, lineHeight: CGFloat?)] = [
            ("HH {image} HH", nil),
            ("# HH {image} HH", nil),
            ("**HH {image} HH**", nil),
            ("HH {image} HH", 48),
            ("> HH {image} HH", 48),
        ]
        for (markdown, lineHeight) in cases {
            let label = "\(markdown), line height \(String(describing: lineHeight))"
            let rows = try paintedRows(try textView(markdown, config: styleConfig(size: 30, lineHeight: lineHeight)))
            XCTAssertEqual(Double(rows.image.count), 30 * scale, accuracy: 1, label)
            XCTAssertEqual(center(of: rows.image), center(of: rows.capitals), accuracy: 1, label)
        }
    }

    func testAnInlineImageIsCentredWithoutATextContainer() throws {
        let text = try render("HH {image} HH", config: styleConfig(size: 30, lineHeight: 48))
        let image = try XCTUnwrap(
            text.attribute(.attachment, at: try imageIndex(in: text), effectiveRange: nil) as? MarkdownImageAttachment
        )
        let font = try XCTUnwrap(text.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
        let lift = text.attribute(.baselineOffset, at: 0, effectiveRange: nil) as? CGFloat ?? 0

        let bounds = image.attachmentBounds(for: nil, proposedLineFragment: .zero, glyphPosition: .zero, characterIndex: 0)
        XCTAssertEqual(bounds.midY, lift + font.capHeight / 2, accuracy: 0.01)
    }

    func testASmallInlineImageKeepsTheLineHeight() throws {
        let config = styleConfig(size: 4, lineHeight: 0, textSize: 10)
        let withImage = try textView("HH {image} HH", config: config)
        let withText = try textView("HH H HH", config: config)
        XCTAssertEqual(height(of: withImage, width: 300), height(of: withText, width: 300), accuracy: 0.5)
    }

    func testAWideInlineImageFitsInsideItsSquare() throws {
        let downloader = DeferredImageDownloader()
        let attachment = MarkdownImageAttachment.attachment(
            for: "https://example.com/\(#function).png",
            config: styleConfig(size: 30),
            isInline: true,
            altText: "",
            downloader: downloader
        )
        let placeholder = attachment.image
        downloader.complete(with: makeImage(width: 64, height: 32))
        try waitUntil("the image is processed") { attachment.image !== placeholder }

        let square = try XCTUnwrap(attachment.image?.cgImage)
        let pixels = Pixels(square.width, square.height) { $0.draw(square, in: CGRect(x: 0, y: 0, width: $1, height: $2)) }
        let red = pixels.points(where: Pixels.isRed)
        let rows = try XCTUnwrap(red.map(\.y).min())...(try XCTUnwrap(red.map(\.y).max()))

        XCTAssertEqual(square.width, square.height, "the square")
        XCTAssertEqual(Double(Set(red.map(\.x)).count), Double(square.width), accuracy: 1, "full width")
        XCTAssertEqual(Double(rows.count), Double(square.height) / 2, accuracy: 1, "half the height")
        XCTAssertEqual(center(of: rows), Double(square.height) / 2, accuracy: 1, "centred")
    }

    // MARK: - Helpers

    private let scale = 2.0

    private func styleConfig(size: CGFloat, lineHeight: CGFloat? = nil, textSize: CGFloat? = nil) -> MarkdownStyleConfiguration {
        var paragraph = textSize.map { Paragraph().font(size: $0) } ?? Paragraph()
        paragraph.lineHeight = lineHeight
        return MarkdownStyleConfiguration.resolve(
            layers: [.default, MarkdownTheme {
                paragraph
                InlineImage().size(size)
                Blockquote().foregroundStyle(.black)
            }],
            traitCollection: .current
        )
    }

    /// `markdown` rendered with a red image for each `{image}`.
    private func render(_ markdown: String, config: MarkdownStyleConfiguration) throws -> NSAttributedString {
        let png = try XCTUnwrap(makeImage(width: 32, height: 32).pngData())
        let image = "![red](data:image/png;base64,\(png.base64EncodedString()))"
        return MarkdownRenderer.render(markdown.replacingOccurrences(of: "{image}", with: image), config: config)
    }

    private func textView(_ markdown: String, config: MarkdownStyleConfiguration) throws -> MarkdownTextView {
        let textView = MarkdownTextView()
        textView.styleConfig = config
        textView.backgroundColor = .white
        textView.setMarkdownAttributedText(try render(markdown, config: config))
        return textView
    }

    private func imageIndex(in text: NSAttributedString) throws -> Int {
        var index: Int?
        text.enumerateAttribute(.attachment, in: NSRange(location: 0, length: text.length)) { value, range, stop in
            guard value is MarkdownImageAttachment else { return }
            index = range.location
            stop.pointee = true
        }
        return try XCTUnwrap(index, "no image")
    }

    private func paintedRows(_ textView: MarkdownTextView) throws -> (image: ClosedRange<Int>, capitals: ClosedRange<Int>) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 400))
        window.addSubview(textView)
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        var pixels = Pixels(0, 0) { _, _, _ in }
        try waitUntil("the image draws") {
            // A whole-point height keeps the bottom row of pixels whole.
            textView.frame = CGRect(x: 0, y: 0, width: 300, height: ceil(height(of: textView, width: 300)))
            textView.layoutIfNeeded()
            pixels = Pixels(Int(300 * scale), Int(textView.frame.height * scale)) { context, _, height in
                context.translateBy(x: 0, y: height)
                context.scaleBy(x: scale, y: -scale)
                textView.layer.render(in: context)
            }
            return !pixels.points(where: Pixels.isRed).isEmpty
        }
        let red = pixels.points(where: Pixels.isRed)
        let imageEnd = try XCTUnwrap(red.map(\.x).max())
        let capitals = pixels.points(where: Pixels.isDark).filter { $0.x > imageEnd + 2 }.map(\.y)
        return (
            try XCTUnwrap(red.map(\.y).min())...(try XCTUnwrap(red.map(\.y).max())),
            try XCTUnwrap(capitals.min())...(try XCTUnwrap(capitals.max()))
        )
    }

    private func center(of rows: ClosedRange<Int>) -> Double {
        Double(rows.lowerBound + rows.upperBound + 1) / 2
    }

    /// Runs the main run loop until `condition` holds, failing after `timeout`.
    private func waitUntil(_ description: String, timeout: TimeInterval = 5, _ condition: () throws -> Bool) throws {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while try !condition() {
            guard Date() < deadline else { return XCTFail("Timed out waiting until \(description)") }
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        }
    }
}

/// RGBA pixels drawn into a bitmap, top row first.
private struct Pixels {
    private var bytes: [UInt8]
    private let width: Int

    init(_ width: Int, _ height: Int, draw: (CGContext, CGFloat, CGFloat) -> Void) {
        self.width = width
        bytes = [UInt8](repeating: 0, count: width * height * 4)
        bytes.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return }
            draw(context, CGFloat(width), CGFloat(height))
        }
    }

    static func isRed(_ red: UInt8, _ green: UInt8, _ blue: UInt8) -> Bool {
        red > 200 && green < 80 && blue < 80
    }

    static func isDark(_ red: UInt8, _ green: UInt8, _ blue: UInt8) -> Bool {
        max(red, green, blue) < 90
    }

    func points(where matches: (UInt8, UInt8, UInt8) -> Bool) -> [(x: Int, y: Int)] {
        stride(from: 0, to: bytes.count, by: 4).compactMap { offset in
            guard bytes[offset + 3] > 200, matches(bytes[offset], bytes[offset + 1], bytes[offset + 2]) else { return nil }
            return (x: offset / 4 % width, y: offset / 4 / width)
        }
    }
}
