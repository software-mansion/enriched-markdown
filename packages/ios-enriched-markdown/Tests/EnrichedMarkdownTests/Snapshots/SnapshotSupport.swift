import UIKit
import XCTest
@testable import EnrichedMarkdown

/// Renders markdown through the real display pipeline into a full-content image
/// and compares it pixel-for-pixel against a committed golden PNG.
///
/// Unlike the device-screenshot e2e flows, the view is rendered in-process at its
/// intrinsic size, so tall content is never clipped by a viewport, and the result
/// does not depend on any surrounding app layout.
@MainActor
enum Snapshot {
    static let renderWidth: CGFloat = 390
    static let scale: CGFloat = 3

    private static let recordMode: Bool =
        ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "1"

    /// Light mode, standard type size — pinned so goldens don't depend on
    /// simulator settings.
    private static let traits: UITraitCollection = UITraitCollection(traitsFrom: [
        UITraitCollection(userInterfaceStyle: .light),
        UITraitCollection(preferredContentSizeCategory: .large),
    ])

    private static let window: UIWindow = {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: renderWidth, height: 100))
        window.backgroundColor = .white
        window.isHidden = false
        return window
    }()

    // MARK: - Rendering

    static func verify(
        _ snapshotCase: RenderSnapshotCase,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let markdown = SnapshotFixtures.substituteImageTokens(in: snapshotCase.markdown)
        let expectsImages = markdown != snapshotCase.markdown

        let config = MarkdownStyleConfig.resolve(layers: [.default], traitCollection: traits)
        let attributed = MarkdownRenderer.render(markdown, config: config, flags: snapshotCase.flags)

        let textView = MarkdownTextView()
        textView.styleConfig = config
        textView.backgroundColor = .white
        window.addSubview(textView)
        defer { textView.removeFromSuperview() }

        guard let image = captureStableImage(of: textView, attributed: attributed, expectsImages: expectsImages) else {
            XCTFail("\(snapshotCase.name): render never stabilized", file: file, line: line)
            return
        }

        assertMatchesGolden(image, named: snapshotCase.name, file: file, line: line)
    }

    /// Captures repeatedly, spinning the run loop between captures, until two
    /// consecutive captures are identical. This absorbs every async source at
    /// once: the two-pass TextKit height settle, decoration redraws, and image
    /// attachments loading off the main queue.
    private static func captureStableImage(
        of textView: MarkdownTextView,
        attributed: NSAttributedString,
        expectsImages: Bool
    ) -> UIImage? {
        textView.setMarkdownAttributedText(attributed)
        layout(textView)

        let initial = capture(textView)
        var previous = initial
        var deadline = Date(timeIntervalSinceNow: 5)

        // With image attachments the placeholder state is itself stable, so first
        // wait for the render to move past the initial frame.
        if expectsImages {
            while Date() < deadline {
                spinRunLoop()
                layout(textView)
                let current = capture(textView)
                if current.pngData() != initial.pngData() {
                    previous = current
                    break
                }
            }
        }

        deadline = Date(timeIntervalSinceNow: 5)
        while Date() < deadline {
            spinRunLoop()
            layout(textView)
            let current = capture(textView)
            if let a = current.pngData(), let b = previous.pngData(), a == b {
                return current
            }
            previous = current
        }
        return nil
    }

    private static func layout(_ textView: MarkdownTextView) {
        let size = textView.sizeThatFits(
            CGSize(width: renderWidth, height: .greatestFiniteMagnitude)
        )
        textView.frame = CGRect(x: 0, y: 0, width: renderWidth, height: ceil(size.height))
        textView.layoutIfNeeded()
    }

    private static func spinRunLoop(for interval: TimeInterval = 0.05) {
        RunLoop.main.run(until: Date(timeIntervalSinceNow: interval))
    }

    private static func capture(_ view: UIView) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        format.preferredRange = .standard
        let renderer = UIGraphicsImageRenderer(bounds: view.bounds, format: format)
        return renderer.image { context in
            view.layer.render(in: context.cgContext)
        }
    }

    // MARK: - Golden comparison

    private static func goldenURL(named name: String) -> URL {
        URL(fileURLWithPath: "\(#filePath)")
            .deletingLastPathComponent()
            .appendingPathComponent("__Snapshots__")
            .appendingPathComponent("\(name).png")
    }

    private static func assertMatchesGolden(
        _ image: UIImage,
        named name: String,
        file: StaticString,
        line: UInt
    ) {
        let goldenURL = goldenURL(named: name)
        guard let actualData = image.pngData() else {
            XCTFail("\(name): could not encode PNG", file: file, line: line)
            return
        }

        if recordMode || !FileManager.default.fileExists(atPath: goldenURL.path) {
            do {
                try actualData.write(to: goldenURL)
                XCTFail(
                    "\(name): recorded golden (\(Int(image.size.width))x\(Int(image.size.height))pt) — re-run without record mode",
                    file: file,
                    line: line
                )
            } catch {
                XCTFail("\(name): failed to write golden: \(error)", file: file, line: line)
            }
            return
        }

        guard let golden = UIImage(contentsOfFile: goldenURL.path) else {
            XCTFail("\(name): could not load golden at \(goldenURL.path)", file: file, line: line)
            return
        }

        guard let goldenPixels = rgbaPixels(of: golden), let actualPixels = rgbaPixels(of: image) else {
            XCTFail("\(name): could not rasterize for comparison", file: file, line: line)
            return
        }

        if goldenPixels.size != actualPixels.size {
            attachArtifacts(name: name, golden: golden, actual: image, diff: nil)
            XCTFail(
                "\(name): size mismatch — golden \(goldenPixels.size), actual \(actualPixels.size)",
                file: file,
                line: line
            )
            return
        }

        if goldenPixels.bytes == actualPixels.bytes { return }

        let totalPixels = Int(goldenPixels.size.width * goldenPixels.size.height)
        var differing = 0
        var diffBytes = actualPixels.bytes
        for pixel in 0..<totalPixels {
            let offset = pixel * 4
            if goldenPixels.bytes[offset..<offset + 4] != actualPixels.bytes[offset..<offset + 4] {
                differing += 1
                diffBytes[offset] = 255
                diffBytes[offset + 1] = 0
                diffBytes[offset + 2] = 0
                diffBytes[offset + 3] = 255
            }
        }
        let matchPercentage = 100.0 * Double(totalPixels - differing) / Double(totalPixels)
        attachArtifacts(
            name: name,
            golden: golden,
            actual: image,
            diff: imageFromRGBA(diffBytes, size: goldenPixels.size)
        )
        XCTFail(
            String(format: "%@: %d of %d pixels differ (%.2f%% match, required 100%%)", name, differing, totalPixels, matchPercentage),
            file: file,
            line: line
        )
    }

    // MARK: - Pixel access

    private struct PixelBuffer {
        let bytes: [UInt8]
        let size: CGSize
    }

    private static func rgbaPixels(of image: UIImage) -> PixelBuffer? {
        guard let cgImage = image.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return PixelBuffer(bytes: bytes, size: CGSize(width: width, height: height))
    }

    private static func imageFromRGBA(_ bytes: [UInt8], size: CGSize) -> UIImage? {
        var mutableBytes = bytes
        guard let context = CGContext(
            data: &mutableBytes,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(size.width) * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let cgImage = context.makeImage() else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private static func attachArtifacts(name: String, golden: UIImage, actual: UIImage, diff: UIImage?) {
        let expected = XCTAttachment(image: golden)
        expected.name = "\(name)_expected"
        expected.lifetime = .keepAlways
        XCTContext.runActivity(named: "\(name) snapshot mismatch") { activity in
            activity.add(expected)
            let actualAttachment = XCTAttachment(image: actual)
            actualAttachment.name = "\(name)_actual"
            actualAttachment.lifetime = .keepAlways
            activity.add(actualAttachment)
            if let diff {
                let diffAttachment = XCTAttachment(image: diff)
                diffAttachment.name = "\(name)_diff"
                diffAttachment.lifetime = .keepAlways
                activity.add(diffAttachment)
            }
        }
    }
}

/// Deterministic solid-color image fixtures written to the temporary directory,
/// substituted for the {{IMAGE}}/{{ICON}} tokens in ported flow markdown.
enum SnapshotFixtures {
    static let blockImageURL: URL = writeFixture(
        named: "snapshot_logo.png",
        size: CGSize(width: 120, height: 80),
        color: .systemBlue
    )

    static let inlineImageURL: URL = writeFixture(
        named: "snapshot_icon.png",
        size: CGSize(width: 24, height: 24),
        color: .systemOrange
    )

    static func substituteImageTokens(in markdown: String) -> String {
        markdown
            .replacingOccurrences(of: "{{IMAGE}}", with: blockImageURL.absoluteString)
            .replacingOccurrences(of: "{{ICON}}", with: inlineImageURL.absoluteString)
    }

    private static func writeFixture(named name: String, size: CGSize, color: UIColor) -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        // A failed fixture write surfaces as a missing-image snapshot diff.
        try? image.pngData()?.write(to: url)
        return url
    }
}
