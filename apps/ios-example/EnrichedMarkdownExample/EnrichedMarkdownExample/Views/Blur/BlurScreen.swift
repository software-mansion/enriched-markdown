import EnrichedMarkdown
import SwiftUI

/// The README's custom overlay on its own page: `BlurOverlayProvider` draws
/// each hidden phrase as frosted glass made from the text itself, so the
/// page is a night sky with one bright pane of glass on it.
private let blurMarkdown = """
## Spoiler alert 🎬

Tap a blurred phrase to read it.

**The Sixth Sense:** ||Malcolm is a ghost.||

**Fight Club:** ||Tyler isn't real.||

**The Empire Strikes Back:** ||Vader is Luke's father.||

> Long spoilers wrap, and every line blurs on its own: ||Rosebud was the sled Kane lost the day he left home for good.||

Enjoy the show 🍿
"""

private enum FrostPalette {
    static let night = Color(red: 0.03, green: 0.05, blue: 0.14)
    static let ice = Color(red: 0.42, green: 0.66, blue: 1.0)
    static let violet = Color(red: 0.45, green: 0.32, blue: 0.95)
    static let muted = Color(red: 0.70, green: 0.75, blue: 0.88)
    static let pane = Color.white
}

/// Card styling; the spoiler backdrop matches the pane, so the opaque blur
/// sits invisibly on it.
private let blurTheme = MarkdownTheme {
    Paragraph()
        .font(size: 17, design: .rounded)
        .foregroundStyle(Color.gray800)
        .lineHeight(26)
        .marginBottom(14)

    Heading(2)
        .font(size: 24, weight: .bold, design: .rounded)
        .foregroundStyle(Color.gray900)
        .marginBottom(10)

    Strong()
        .foregroundStyle(Color.gray900)

    Blockquote()
        .font(size: 16, design: .rounded)
        .foregroundStyle(Color.gray600)
        .lineHeight(24)
        .backgroundStyle(FrostPalette.pane)
        .border(Color.brandMint, width: 3)
        .gapWidth(14)
        .marginBottom(14)

    Spoiler()
        .background(FrostPalette.pane)
}

struct BlurScreen: View {
    // MARK: - Properties

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Views

    var body: some View {
        ZStack {
            FrostBackdrop(animates: !reduceMotion)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    pane
                    snippet
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .background(FrostPalette.night)
        .accessibilityIdentifier("blur-screen")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CUSTOM OVERLAY")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(3)
                .foregroundStyle(Color.brandMint)

            Text("Blur")
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white)
                .shadow(color: FrostPalette.ice.opacity(0.45), radius: 16)

            Text("Frosted glass drawn from the hidden text.")
                .font(.system(size: 16, design: .rounded))
                .foregroundStyle(FrostPalette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The one bright pane: solid white, so the opaque blur views match it.
    private var pane: some View {
        EnrichedMarkdownText(blurMarkdown)
            .markdownTheme(blurTheme)
            .markdownSpoilerOverlay(BlurOverlayProvider())
            .markdownTextSelection(.disabled)
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(FrostPalette.pane)
                    .shadow(color: Color.black.opacity(0.45), radius: 30, y: 16)
                    .shadow(color: FrostPalette.ice.opacity(0.25), radius: 40)
            }
            .overlay {
                // A hairline of light along the top edge, as on real glass.
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white, Color.white.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .center
                        ),
                        lineWidth: 1.5
                    )
            }
    }

    private var snippet: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.brandMint)
                .padding(.top, 1)

            Text("EnrichedMarkdownText(markdown)\n  .markdownSpoilerOverlay(BlurOverlayProvider())")
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                .lineSpacing(2)
                .foregroundStyle(Color.white.opacity(0.92))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FrostChrome(cornerRadius: 14))
    }
}

// MARK: - Chrome

/// Translucent panel with a hairline border, for controls on the night sky.
private struct FrostChrome: View {
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.white.opacity(0.07))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14))
            )
    }
}

// MARK: - Backdrop

/// Three soft lights drifting over the night, drawn with `Canvas` and
/// additive blending so overlaps glow rather than muddy.
private struct FrostBackdrop: View {
    let animates: Bool

    private struct Glow {
        let color: Color
        let orbit: CGSize
        let radius: CGFloat
        let speed: Double
    }

    private let glows = [
        Glow(color: Color.brandMint, orbit: CGSize(width: 0.35, height: 0.22), radius: 0.55, speed: 0.16),
        Glow(color: FrostPalette.ice, orbit: CGSize(width: 0.40, height: 0.26), radius: 0.5, speed: 0.12),
        Glow(color: FrostPalette.violet, orbit: CGSize(width: 0.30, height: 0.30), radius: 0.45, speed: 0.2)
    ]

    var body: some View {
        TimelineView(.animation(paused: !animates)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                context.blendMode = .plusLighter
                for (index, glow) in glows.enumerated() {
                    let phase = time * glow.speed + Double(index) * 2.1
                    let center = CGPoint(
                        x: size.width * (0.5 + glow.orbit.width * cos(phase)),
                        y: size.height * (0.4 + glow.orbit.height * sin(phase * 0.8))
                    )
                    let radius = min(size.width, size.height) * glow.radius
                    let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .radialGradient(
                            Gradient(colors: [glow.color.opacity(0.38), glow.color.opacity(0)]),
                            center: center,
                            startRadius: 0,
                            endRadius: radius
                        )
                    )
                }
            }
        }
        .background(FrostPalette.night)
    }
}

// MARK: -

#Preview {
    NavigationStack {
        BlurScreen()
            .immersiveNavigationBar()
    }
}
