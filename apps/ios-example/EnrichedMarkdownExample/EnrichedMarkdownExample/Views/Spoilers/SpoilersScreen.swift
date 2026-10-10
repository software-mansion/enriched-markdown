import EnrichedMarkdown
import SwiftUI

private let showcaseMarkdown = """
## Spoiler alert 🎬

Tap to reveal. Every effect above is a `SpoilerOverlayView` subclass.

**The Sixth Sense:** ||Malcolm is a ghost.||

**Fight Club:** ||Tyler isn't real.||

**Empire Strikes Back:** ||Vader is Luke's dad.||

> Long spoilers wrap, and each line gets its own overlay: ||Rosebud was the sled Kane lost the day he left home for good.||

Emoji hide too: ||🍿 popcorn was the twist||
"""

private enum ShowcasePalette {
    static let page = Color(red: 0.03, green: 0.04, blue: 0.09)
    static let card = Color(red: 0.08, green: 0.09, blue: 0.16)
    static let text = Color(red: 0.90, green: 0.92, blue: 0.97)
    static let muted = Color(red: 0.62, green: 0.66, blue: 0.78)
}

/// Dark card styling; the spoiler backdrop matches the card so the particle
/// and text-based overlays blend into it.
private func showcaseTheme(accent: Color) -> MarkdownTheme {
    MarkdownTheme {
        Paragraph()
            .fontSize(17)
            .fontDesign(.rounded)
            .foregroundStyle(ShowcasePalette.text)
            .lineHeight(26)
            .marginBottom(14)

        Heading(2)
            .fontSize(24, weight: .bold)
            .fontDesign(.rounded)
            .foregroundStyle(Color.white)
            .marginBottom(10)

        Strong()
            .foregroundStyle(Color.white)

        Blockquote()
            .fontSize(16)
            .fontDesign(.rounded)
            .foregroundStyle(ShowcasePalette.muted)
            .lineHeight(24)
            .backgroundStyle(ShowcasePalette.card)
            .borderColor(accent)
            .borderWidth(3)
            .gapWidth(14)
            .marginBottom(14)

        Code()
            .foregroundStyle(accent)
            .backgroundStyle(accent.opacity(0.14))

        Spoiler()
            .color(accent)
            .background(ShowcasePalette.card)
    }
}

private let selectionSpring = Animation.spring(response: 0.45, dampingFraction: 0.8)

struct SpoilersScreen: View {
    // MARK: - Properties

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var overlay: SpoilerShowcaseOverlay = .default
    @State private var accent: SpoilerShowcaseAccent = .mint
    /// Bumped on every effect tap; see `concealSuffix`.
    @State private var generation = 0
    @Namespace private var selection

    // MARK: - Views

    var body: some View {
        ZStack {
            AuroraBackdrop(tint: accent.color, animates: !reduceMotion)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    effectPicker
                    card
                    snippet
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .background(ShowcasePalette.page)
        .selectionHaptic(trigger: generation)
        .accessibilityIdentifier("spoilers-screen")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SPOILER OVERLAYS")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(3)
                .foregroundStyle(accent.color)

            Text(overlay.title)
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white)
                .id("title-\(overlay.rawValue)")
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))

            Text(overlay.tagline)
                .font(.system(size: 16, design: .rounded))
                .foregroundStyle(ShowcasePalette.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .id("tagline-\(overlay.rawValue)")
                .transition(.opacity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
    }

    private var effectPicker: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SpoilerShowcaseOverlay.allCases) { item in
                        chip(for: item)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, -20)
            .onChange(of: overlay) { value in
                withAnimation(selectionSpring) {
                    proxy.scrollTo(value, anchor: .center)
                }
            }
        }
    }

    private func chip(for item: SpoilerShowcaseOverlay) -> some View {
        let isSelected = item == overlay
        return Button {
            // Every tap replays the effect: conceal again in the next tint.
            withAnimation(selectionSpring) {
                overlay = item
                accent = accent.next
                generation += 1
            }
        } label: {
            Label(item.title, systemImage: item.symbol)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(isSelected ? ShowcasePalette.page : Color.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(accent.color)
                            .shadow(color: accent.color.opacity(0.6), radius: 12)
                            .matchedGeometryEffect(id: "selected-chip", in: selection)
                    } else {
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.12)))
                    }
                }
        }
        .buttonStyle(.plain)
        .id(item)
        .accessibilityIdentifier("spoiler-effect-\(item.rawValue)")
    }

    /// Spoilers conceal again whenever the markdown string changes, and a
    /// trailing newline renders identically, so toggling one re-hides them
    /// in place. Re-creating the text view instead would empty the card for
    /// a frame and bounce everything below it.
    private var concealSuffix: String {
        generation.isMultiple(of: 2) ? "" : "\n"
    }

    private var card: some View {
        EnrichedMarkdownText(showcaseMarkdown + concealSuffix)
            .markdownTheme(showcaseTheme(accent: accent.color))
            .markdownSpoilerOverlay(overlay.provider)
            .markdownSelectable(false)
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            // The shadow sits on the shape, not the whole card: a shadow on
            // the card would be composited over the text view and tint it,
            // so the opaque spoiler backdrops would no longer match.
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(ShowcasePalette.card)
                    .shadow(color: accent.color.opacity(0.25), radius: 30, y: 12)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [accent.color.opacity(0.7), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
    }

    private var snippet: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(accent.color)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text("EnrichedMarkdownText(markdown)")
                Text("  " + overlay.snippet)
                    .contentTransition(.numericText())
                    .animation(.default, value: overlay)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .foregroundStyle(ShowcasePalette.text)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Backdrop

/// Three soft light blobs drifting behind the content, drawn with `Canvas`
/// and additive blending so overlaps glow rather than muddy.
private struct AuroraBackdrop: View {
    let tint: Color
    let animates: Bool

    private struct Blob {
        let color: Color
        let orbit: CGSize
        let radius: CGFloat
        let speed: Double
    }

    private var blobs: [Blob] {
        [
            Blob(color: tint, orbit: CGSize(width: 0.35, height: 0.25), radius: 0.55, speed: 0.18),
            Blob(
                color: Color(red: 0.45, green: 0.30, blue: 0.95),
                orbit: CGSize(width: 0.30, height: 0.30),
                radius: 0.5,
                speed: 0.13
            ),
            Blob(
                color: Color(red: 0.10, green: 0.55, blue: 0.85),
                orbit: CGSize(width: 0.40, height: 0.20),
                radius: 0.45,
                speed: 0.22
            )
        ]
    }

    var body: some View {
        TimelineView(.animation(paused: !animates)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                context.blendMode = .plusLighter
                for (index, blob) in blobs.enumerated() {
                    let phase = time * blob.speed + Double(index) * 2.1
                    let center = CGPoint(
                        x: size.width * (0.5 + blob.orbit.width * cos(phase)),
                        y: size.height * (0.45 + blob.orbit.height * sin(phase * 0.8))
                    )
                    let radius = min(size.width, size.height) * blob.radius
                    let rect = CGRect(
                        x: center.x - radius,
                        y: center.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .radialGradient(
                            Gradient(colors: [blob.color.opacity(0.45), blob.color.opacity(0)]),
                            center: center,
                            startRadius: 0,
                            endRadius: radius
                        )
                    )
                }
            }
        }
        .background(ShowcasePalette.page)
    }
}

// MARK: - Helpers

private extension View {
    @ViewBuilder
    func selectionHaptic<Trigger: Equatable>(trigger: Trigger) -> some View {
        if #available(iOS 17, *) {
            sensoryFeedback(.selection, trigger: trigger)
        } else {
            self
        }
    }
}

// MARK: -

#Preview {
    NavigationStack {
        SpoilersScreen()
            .immersiveNavigationBar()
    }
}
