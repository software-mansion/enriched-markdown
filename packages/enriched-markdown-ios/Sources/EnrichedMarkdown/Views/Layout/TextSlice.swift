import UIKit

enum TextSlice {
    static func standalone(_ text: NSAttributedString) -> NSAttributedString {
        let slice = NSMutableAttributedString(attributedString: text)
        let all = NSRange(location: 0, length: slice.length)
        slice.removeAttribute(.link, range: all)
        slice.enumerateAttribute(.paragraphStyle, in: all) { value, run, _ in
            guard let paragraph = value as? NSParagraphStyle else { return }
            slice.addAttribute(.paragraphStyle, value: lineStyle(of: paragraph), range: run)
        }
        return slice
    }

    static func image(of text: NSAttributedString, size: CGSize, baseline: CGFloat, traits: UITraitCollection) -> UIImage {
        let bounds = CGRect(origin: .zero, size: size)
        guard !bounds.isEmpty else { return UIImage() }
        let contentStorage = NSTextContentStorage()
        let layoutManager = NSTextLayoutManager()
        contentStorage.addTextLayoutManager(layoutManager)
        let container = SnapshotTextContainer(size: CGSize(width: size.width, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        layoutManager.textContainer = container
        contentStorage.attributedString = text
        layoutManager.ensureLayout(for: layoutManager.documentRange)
        let format = UIGraphicsImageRendererFormat.default()
        format.preferredRange = .standard
        let renderer = UIGraphicsImageRenderer(bounds: bounds, format: format)
        guard let fragment = layoutManager.textLayoutFragment(for: layoutManager.documentRange.location),
              let line = fragment.textLineFragments.first
        else { return renderer.image { _ in } }

        let lineBaseline = fragment.layoutFragmentFrame.minY + line.typographicBounds.minY + line.glyphOrigin.y
        return renderer.image { context in
            traits.performAsCurrent {
                fragment.draw(at: CGPoint(x: 0, y: baseline - lineBaseline), in: context.cgContext)
            }
        }
    }

    private static func lineStyle(of paragraph: NSParagraphStyle) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.minimumLineHeight = paragraph.minimumLineHeight
        style.maximumLineHeight = paragraph.maximumLineHeight
        style.lineSpacing = paragraph.lineSpacing
        style.lineHeightMultiple = paragraph.lineHeightMultiple
        style.baseWritingDirection = paragraph.baseWritingDirection
        style.alignment = paragraph.alignment
        style.lineBreakMode = .byClipping
        return style
    }
}
