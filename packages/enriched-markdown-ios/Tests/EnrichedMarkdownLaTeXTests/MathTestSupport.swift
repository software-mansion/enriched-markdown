import UIKit
import XCTest
@testable import EnrichedMarkdown
@testable import EnrichedMarkdownLaTeX

extension XCTestCase {
    @MainActor
    func hostedTextView(config: MarkdownStyleConfiguration = .baseline(), width: CGFloat = 380) -> (window: UIWindow, textView: MarkdownTextView) {
        let textView = MarkdownTextView()
        textView.styleConfig = config
        textView.frame = CGRect(x: 0, y: 0, width: width, height: 100)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: 1000))
        window.addSubview(textView)
        window.isHidden = false
        return (window, textView)
    }

    @MainActor
    func settle(_ textView: MarkdownTextView) {
        textView.frame.size.height = textView.sizeThatFits(CGSize(width: textView.bounds.width, height: .greatestFiniteMagnitude)).height
        textView.layoutIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
        textView.layoutIfNeeded()
    }
}

extension UIView {
    func firstSubview<T: UIView>(of type: T.Type) -> T? {
        for subview in subviews {
            if let match = subview as? T ?? subview.firstSubview(of: type) {
                return match
            }
        }
        return nil
    }
}

extension XCTestCase {
    /// Deterministic typeset metrics standing in for RaTeX.
    func stubResult() -> MathTypesetResult {
        MathTypesetResult(width: 40, ascent: 12, descent: 4) { _ in }
    }

    func mathAttachments(in rendered: NSAttributedString) -> [MathAttachment] {
        var found: [MathAttachment] = []
        rendered.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: rendered.length)
        ) { value, _, _ in
            if let math = value as? MathAttachment {
                found.append(math)
            }
        }
        return found
    }

    /// True when every pixel is fully transparent.
    func isBlank(_ image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return true }
        let width = cgImage.width
        let height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue
        ) else { return true }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return !pixels.contains { $0 > 0 }
    }
}
