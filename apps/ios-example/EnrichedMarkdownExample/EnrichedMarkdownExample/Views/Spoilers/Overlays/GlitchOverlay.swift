import EnrichedMarkdown
import UIKit

/// A torn signal: cipher glyphs split into red, green and blue copies pulled
/// apart, with a few bands torn sideways, flickering in strength. On reveal
/// the glyphs resolve into the words while the tearing collapses and the
/// channels lock back into clean text.
///
/// Everything is plain Core Graphics: the three channel copies are tinted
/// once per scramble, and a frame is a dozen image draws.
final class GlitchOverlayView: FrameAnimatedOverlayView {
    /// Channel offset at full strength, in points.
    private static let channelSplit: CGFloat = 4
    /// Sideways tear of a band at full strength, in points.
    private static let sliceShift: CGFloat = 10
    private static let sliceCount = 2
    /// Idle frames between cipher changes; the tear still jitters every frame.
    private static let framesPerScramble = 3

    private var clusters: [NSRange] = []
    private var textColor: UIColor = .white
    /// The current cipher text, tinted to the red, green and blue parts of
    /// the text color, so the three add back up to it when aligned.
    private var channels: [CGImage] = []
    private var frameCount = 0

    convenience init(style: SpoilerStyle, charRange: NSRange) {
        self.init(charRange: charRange)
        backgroundColor = style.backgroundColor ?? .systemBackground
        idleFramesPerSecond = 12
        revealDuration = 0.7
        lineStagger = 0.4
    }

    override func prepare() {
        clusters = concealedClusters()
        textColor = concealedText.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor ?? .white
        scramble(resolvedFraction: 0)
    }

    override func draw(progress: Double?) {
        let resolvedFraction = progress.map { 1 - pow(1 - $0, 2) } ?? 0
        // Full tear while idle, flickering in strength; on reveal it decays.
        let intensity = progress.map { pow(1 - $0, 1.5) } ?? Double.random(in: 0.5...1)
        frameCount += 1
        if progress != nil || frameCount.isMultiple(of: Self.framesPerScramble) {
            scramble(resolvedFraction: resolvedFraction)
        }
        guard let first = channels.first else { return }

        let width = CGFloat(first.width)
        let height = CGFloat(first.height)
        let split = Self.channelSplit * displayScale * intensity
        var bands: [(rect: CGRect, shift: CGFloat)] = [(CGRect(x: 0, y: 0, width: width, height: height), 0)]
        if intensity > 0.05 {
            for _ in 0..<Self.sliceCount {
                let bandHeight = CGFloat.random(in: height * 0.15...height * 0.35).rounded()
                let bandY = CGFloat.random(in: 0...(height - bandHeight)).rounded()
                let shift = CGFloat.random(in: -Self.sliceShift...Self.sliceShift) * displayScale * intensity
                bands.append((CGRect(x: 0, y: bandY, width: width, height: bandHeight), shift))
            }
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            let cgContext = context.cgContext
            cgContext.translateBy(x: 0, y: height)
            cgContext.scaleBy(x: 1, y: -1)
            for band in bands {
                // Image rows count from the top; the flipped context from the bottom.
                let target = CGRect(x: 0, y: height - band.rect.maxY, width: band.rect.width, height: band.rect.height)
                cgContext.clear(target)
                cgContext.setBlendMode(glowBlend)
                for (index, channel) in channels.enumerated() {
                    guard let piece = channel.cropping(to: band.rect) else { continue }
                    let channelOffset = index == 0 ? split : index == 2 ? -split : 0
                    cgContext.draw(piece, in: target.offsetBy(dx: band.shift + channelOffset, dy: 0))
                }
                cgContext.setBlendMode(.normal)
            }
        }
        layer.contents = image.cgImage
    }

    private func scramble(resolvedFraction: Double) {
        let text = scrambledConcealedText(clusters: clusters, resolvedFraction: resolvedFraction, glyphColor: textColor)
        guard let base = concealedTextImage(text).cgImage else { return }
        var red: CGFloat = 1, green: CGFloat = 1, blue: CGFloat = 1, alpha: CGFloat = 1
        textColor.resolvedColor(with: traitCollection).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let parts = [
            UIColor(red: red, green: 0, blue: 0, alpha: 1),
            UIColor(red: 0, green: green, blue: 0, alpha: 1),
            UIColor(red: 0, green: 0, blue: blue, alpha: 1)
        ]

        let size = CGSize(width: base.width, height: base.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        channels = parts.compactMap { part in
            UIGraphicsImageRenderer(size: size, format: format).image { context in
                let cgContext = context.cgContext
                cgContext.translateBy(x: 0, y: size.height)
                cgContext.scaleBy(x: 1, y: -1)
                cgContext.draw(base, in: CGRect(origin: .zero, size: size))
                cgContext.setBlendMode(.sourceAtop)
                cgContext.setFillColor(part.cgColor)
                cgContext.fill(CGRect(origin: .zero, size: size))
            }.cgImage
        }
    }
}

struct GlitchOverlayProvider: SpoilerOverlayProvider {
    func makeOverlay(charRange: NSRange, style: SpoilerStyle) -> SpoilerOverlayView {
        GlitchOverlayView(style: style, charRange: charRange)
    }
}
