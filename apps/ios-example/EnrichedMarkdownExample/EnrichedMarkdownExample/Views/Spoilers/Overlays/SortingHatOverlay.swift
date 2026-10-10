import EnrichedMarkdown
import UIKit

/// The Sorting Hat: cipher glyphs mutter in place of the words, each one
/// flickering between the four house colors. On reveal the muttering speeds
/// up, the Hat decides, and every glyph resolves into the words in the
/// chosen house's color with a glow, before cooling to plain text.
final class SortingHatOverlayView: FrameAnimatedOverlayView {
    private static let houses = [
        UIColor(red: 0.78, green: 0.13, blue: 0.13, alpha: 1),
        UIColor(red: 0.12, green: 0.55, blue: 0.3, alpha: 1),
        UIColor(red: 0.2, green: 0.4, blue: 0.85, alpha: 1),
        UIColor(red: 0.93, green: 0.78, blue: 0.15, alpha: 1)
    ]
    /// Idle frames between mutters, and the reveal share at which it decides.
    private static let framesPerMutter = 4
    private static let decision = 0.55

    private var clusters: [NSRange] = []
    private var houseOf: [Int] = []
    private var chosen = 0
    private var frameCount = 0
    private var cached: CGImage?

    convenience init(style: SpoilerStyle, charRange: NSRange) {
        self.init(charRange: charRange)
        backgroundColor = style.backgroundColor ?? .systemBackground
        idleFramesPerSecond = 16
        revealDuration = 1.2
        lineStagger = 0.45
    }

    override func prepare() {
        clusters = concealedClusters()
        houseOf = clusters.map { _ in Int.random(in: 0..<Self.houses.count) }
        chosen = Int.random(in: 0..<Self.houses.count)
    }

    override func draw(progress: Double?) {
        frameCount += 1
        guard let progress else {
            if frameCount.isMultiple(of: Self.framesPerMutter) || cached == nil {
                reassign(every: 3)
                cached = mutter(resolvedFraction: 0, decided: 0)
            }
            layer.contents = cached
            return
        }
        // Muttering quickens up to the decision, then the words resolve.
        let decided = CGFloat(max(0, (progress - Self.decision) / (1 - Self.decision)))
        if progress < Self.decision {
            reassign(every: 1)
        }
        let resolved = Double(1 - pow(1 - decided, 2))
        guard let glyphs = mutter(resolvedFraction: resolved, decided: decided) else { return }
        layer.contents = announce(glyphs, decided: decided)
    }

    /// The decision: the line pops and flashes in the chosen house's color,
    /// glowing as the glyphs resolve.
    private func announce(_ glyphs: CGImage, decided: CGFloat) -> CGImage? {
        guard decided > 0 else { return glyphs }
        let size = CGSize(width: glyphs.width, height: glyphs.height)
        let rect = CGRect(origin: .zero, size: size)
        let house = Self.houses[chosen]
        let pop = 1 + 0.1 * CGFloat(sin(Double(decided) * .pi))
        let flash = max(0, 1 - decided / 0.3)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cgContext = context.cgContext
            cgContext.translateBy(x: rect.midX, y: rect.midY)
            cgContext.scaleBy(x: pop, y: pop)
            cgContext.translateBy(x: -rect.midX, y: -rect.midY)
            cgContext.setShadow(offset: .zero, blur: 7 * displayScale, color: house.withAlphaComponent(1 - decided).cgColor)
            cgContext.draw(glyphs, in: rect)
            cgContext.setShadow(offset: .zero, blur: 0, color: nil)
            drawFlash(in: cgContext, rect: rect, color: house, alpha: 0.35 * flash)
        }.cgImage
    }

    /// Gives every `every`th glyph a new house.
    private func reassign(every: Int) {
        for index in houseOf.indices where Int.random(in: 0..<every) == 0 {
            houseOf[index] = Int.random(in: 0..<Self.houses.count)
        }
    }

    /// The glyphs, each in its house color, the resolved ones in the chosen
    /// house's color fading to the text's own as `decided` completes.
    /// Working back to front keeps the earlier ranges valid as clusters are
    /// swapped for single glyphs.
    private func mutter(resolvedFraction: Double, decided: CGFloat) -> CGImage? {
        let text = NSMutableAttributedString(attributedString: concealedText)
        let resolvedCount = Int((Double(clusters.count) * resolvedFraction).rounded(.down))
        let source = concealedText.string as NSString
        for (index, range) in clusters.enumerated().reversed() where index < houseOf.count {
            guard source.substring(with: range).rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { continue }
            if index < resolvedCount {
                let original = text.attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? UIColor ?? .white
                text.addAttribute(.foregroundColor, value: blend(Self.houses[chosen], original, by: decided), range: range)
            } else {
                let glyph = String(cipherGlyphs.randomElement() ?? "#")
                text.replaceCharacters(in: range, with: glyph)
                text.addAttribute(
                    .foregroundColor, value: Self.houses[houseOf[index]],
                    range: NSRange(location: range.location, length: (glyph as NSString).length)
                )
            }
        }
        return concealedTextImage(text).cgImage
    }

    private func blend(_ from: UIColor, _ target: UIColor, by amount: CGFloat) -> UIColor {
        var red1: CGFloat = 0, green1: CGFloat = 0, blue1: CGFloat = 0, alpha1: CGFloat = 0
        var red2: CGFloat = 0, green2: CGFloat = 0, blue2: CGFloat = 0, alpha2: CGFloat = 0
        from.getRed(&red1, green: &green1, blue: &blue1, alpha: &alpha1)
        target.getRed(&red2, green: &green2, blue: &blue2, alpha: &alpha2)
        return UIColor(
            red: red1 + (red2 - red1) * amount, green: green1 + (green2 - green1) * amount,
            blue: blue1 + (blue2 - blue1) * amount, alpha: 1
        )
    }
}

struct SortingHatOverlayProvider: SpoilerOverlayProvider {
    func makeOverlay(charRange: NSRange, style: SpoilerStyle) -> SpoilerOverlayView {
        SortingHatOverlayView(style: style, charRange: charRange)
    }
}
