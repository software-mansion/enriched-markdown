import Combine
import UIKit
import XCTest
@testable import EnrichedMarkdown

extension XCTestCase {
    func height(of textView: MarkdownTextView, width: CGFloat = 200) -> CGFloat {
        textView.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)).height
    }

    func drainMainQueue(for interval: TimeInterval = 0.3) {
        RunLoop.main.run(until: Date(timeIntervalSinceNow: interval))
    }

    func awaitPublished<Value>(
        _ publisher: Published<Value>.Publisher,
        timeout: TimeInterval = 5,
        where matches: @escaping (Value) -> Bool
    ) {
        let published = expectation(description: "published value")
        let cancellable = publisher.filter(matches).first().sink { _ in published.fulfill() }
        wait(for: [published], timeout: timeout)
        cancellable.cancel()
    }

    func attachments<Attachment: NSTextAttachment>(of type: Attachment.Type, in text: NSAttributedString) -> [Attachment] {
        var found: [Attachment] = []
        text.enumerateAttribute(.attachment, in: NSRange(location: 0, length: text.length)) { value, _, _ in
            if let attachment = value as? Attachment {
                found.append(attachment)
            }
        }
        return found
    }

    @MainActor
    func snapshot(of view: UIView, presentation: Bool = false) -> UIImage {
        if presentation {
            CATransaction.flush()
        }
        let layer = presentation ? view.layer.presentation() ?? view.layer : view.layer
        return UIGraphicsImageRenderer(bounds: view.bounds).image { context in layer.render(in: context.cgContext) }
    }

    func inkBounds(of image: UIImage, in rect: CGRect, matching color: UIColor? = nil) -> CGRect? {
        guard let cgImage = image.cgImage else { return nil }
        let scale = image.scale
        let width = cgImage.width, height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }

        let target = color.map { color -> [Int] in
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
            color.getRed(&red, green: &green, blue: &blue, alpha: nil)
            return [red, green, blue].map { Int($0 * 255) }
        }
        func isInk(_ index: Int) -> Bool {
            guard pixels[index + 3] > 64 else { return false }
            guard let target else { return true }
            return (0..<3).allSatisfy { abs(Int(pixels[index + $0]) - target[$0]) <= 60 }
        }

        let columns = max(0, Int(rect.minX * scale))..<min(width, Int(rect.maxX * scale))
        let rows = max(0, Int(rect.minY * scale))..<min(height, Int(rect.maxY * scale))
        var minX = Int.max, maxX = -1, minY = Int.max, maxY = -1
        for row in rows {
            for column in columns where isInk((row * width + column) * 4) {
                minX = min(minX, column); maxX = max(maxX, column)
                minY = min(minY, row); maxY = max(maxY, row)
            }
        }
        guard maxX >= 0 else { return nil }
        return CGRect(
            x: (CGFloat(minX) - rect.minX * scale) / scale,
            y: (CGFloat(minY) - rect.minY * scale) / scale,
            width: CGFloat(maxX - minX + 1) / scale,
            height: CGFloat(maxY - minY + 1) / scale
        )
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

func XCTAssertEqual(_ lhs: CGRect, _ rhs: CGRect, accuracy: CGFloat, _ message: String = "",
                    file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(lhs.minX, rhs.minX, accuracy: accuracy, message, file: file, line: line)
    XCTAssertEqual(lhs.minY, rhs.minY, accuracy: accuracy, message, file: file, line: line)
    XCTAssertEqual(lhs.width, rhs.width, accuracy: accuracy, message, file: file, line: line)
    XCTAssertEqual(lhs.height, rhs.height, accuracy: accuracy, message, file: file, line: line)
}
