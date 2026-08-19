import UIKit

final class ThematicBreakAttachment: NSTextAttachment {
    var lineColor: UIColor = .separator
    var lineHeight: CGFloat = 1
    var marginTop: CGFloat = 0
    var marginBottom: CGFloat = 0

    override func attachmentBounds(
        for textContainer: NSTextContainer?,
        proposedLineFragment lineFrag: CGRect,
        glyphPosition position: CGPoint,
        characterIndex charIndex: Int
    ) -> CGRect {
        let totalHeight = marginTop + lineHeight + marginBottom
        return CGRect(x: 0, y: 0, width: lineFrag.width, height: totalHeight)
    }

    override func image(
        forBounds imageBounds: CGRect,
        textContainer: NSTextContainer?,
        characterIndex charIndex: Int
    ) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: imageBounds.size)
        return renderer.image { context in
            let lineY = marginTop + (lineHeight / 2)
            context.cgContext.setStrokeColor(lineColor.cgColor)
            context.cgContext.setLineWidth(lineHeight)
            context.cgContext.move(to: CGPoint(x: 0, y: lineY))
            context.cgContext.addLine(to: CGPoint(x: imageBounds.width, y: lineY))
            context.cgContext.strokePath()
        }
    }
}
