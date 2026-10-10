import EnrichedMarkdown
import SwiftUI

/// The four houses: each tap of a spell moves to the next one's colors.
private enum House: CaseIterable {
    case gryffindor
    case slytherin
    case ravenclaw
    case hufflepuff

    var name: String {
        switch self {
        case .gryffindor: return "Gryffindor"
        case .slytherin: return "Slytherin"
        case .ravenclaw: return "Ravenclaw"
        case .hufflepuff: return "Hufflepuff"
        }
    }

    /// A lighter tint of the accent that reads on the night sky.
    var glow: Color {
        switch self {
        case .gryffindor: return Color(red: 0.95, green: 0.4, blue: 0.4)
        case .slytherin: return Color(red: 0.4, green: 0.85, blue: 0.55)
        case .ravenclaw: return Color(red: 0.5, green: 0.68, blue: 1)
        case .hufflepuff: return Color(red: 1, green: 0.82, blue: 0.35)
        }
    }

    /// The color spoilers and highlights take.
    var accent: Color {
        switch self {
        case .gryffindor: return Color(red: 0.66, green: 0.1, blue: 0.12)
        case .slytherin: return Color(red: 0.08, green: 0.4, blue: 0.24)
        case .ravenclaw: return Color(red: 0.08, green: 0.22, blue: 0.5)
        case .hufflepuff: return Color(red: 0.8, green: 0.6, blue: 0.08)
        }
    }

    var next: Self {
        let all = Self.allCases
        return all[((all.firstIndex(of: self) ?? 0) + 1) % all.count]
    }
}

/// Parchment styling; the spoiler backdrop matches the page so the opaque
/// overlays sit invisibly on it.
private func spellbookTheme(accent: Color) -> MarkdownTheme {
    MarkdownTheme {
        Paragraph()
            .fontFamily(HogwartsFont.body, size: 18)
            .foregroundStyle(HogwartsPalette.ink)
            .lineHeight(27)
            .marginBottom(12)

        Heading(2)
            .fontFamily(HogwartsFont.display, size: 19)
            .foregroundStyle(HogwartsPalette.leather)
            .marginBottom(12)

        // IM Fell has no bold; small caps carry the emphasis instead.
        Strong()
            .fontFamily(HogwartsFont.smallCaps, size: 18)
            .foregroundStyle(HogwartsPalette.ink)

        Emphasis()
            .fontFamily(HogwartsFont.bodyItalic, size: 18)
            .foregroundStyle(HogwartsPalette.inkSoft)

        Blockquote()
            .fontFamily(HogwartsFont.bodyItalic, size: 18)
            .foregroundStyle(HogwartsPalette.inkSoft)
            .lineHeight(27)
            // The library's default quote background is a light gray; the
            // page color keeps the quote, and any overlay in it, invisible.
            .backgroundStyle(HogwartsPalette.parchment)
            .borderColor(accent)
            .borderWidth(3)
            .gapWidth(14)
            .marginBottom(12)

        // The incantation, stamped on a darker patch of parchment.
        Code()
            .fontFamily(HogwartsFont.smallCaps, size: 17)
            .foregroundStyle(HogwartsPalette.leather)
            .backgroundStyle(Color(red: 0.86, green: 0.78, blue: 0.6))

        // A phrase marked with a wax-crayon wash.
        Highlight()
            .foregroundStyle(HogwartsPalette.ink)
            .background(Color(red: 0.98, green: 0.84, blue: 0.42).opacity(0.55))

        Strikethrough()
            .foregroundStyle(HogwartsPalette.inkSoft)

        ThematicBreak()
            .color(HogwartsPalette.goldDeep)
            .height(1)
            .marginTop(4)
            .marginBottom(14)

        Spoiler()
            .color(accent)
            .background(HogwartsPalette.parchment)
    }
}

private let spellSpring = Animation.spring(response: 0.45, dampingFraction: 0.8)

struct HogwartsScreen: View {
    // MARK: - Properties

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spell: SpoilerShowcaseOverlay = .revelio
    @State private var house: House = .gryffindor
    /// Bumped on every spell tap; see `concealSuffix`.
    @State private var generation = 0
    @Namespace private var selection

    // MARK: - Views

    var body: some View {
        ZStack {
            GreatHallBackdrop(animates: !reduceMotion)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    spellPicker
                    page
                    snippet
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .background(HogwartsPalette.night)
        .selectionHaptic(trigger: generation)
        .accessibilityIdentifier("hogwarts-screen")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(house.name.uppercased())
                .font(.custom(HogwartsFont.caps, size: 11))
                .tracking(5)
                .foregroundStyle(house.glow)
                .id("house-\(house.name)")
                .transition(.opacity)

            Text(spell.title)
                .font(.custom(HogwartsFont.display, size: 30))
                .foregroundStyle(
                    LinearGradient(
                        colors: [HogwartsPalette.gold, Color(red: 0.98, green: 0.88, blue: 0.6), HogwartsPalette.goldDeep],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: HogwartsPalette.gold.opacity(0.55), radius: 12)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .id("spell-\(spell.rawValue)")
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))

            Text(spell.tagline)
                .font(.custom(HogwartsFont.bodyItalic, size: 17))
                .foregroundStyle(HogwartsPalette.parchment.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .id("tagline-\(spell.rawValue)")
                .transition(.opacity)

            ornament
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
    }

    /// A thin gold rule with a diamond, the kind that closes a chapter.
    private var ornament: some View {
        HStack(spacing: 6) {
            Rectangle().fill(HogwartsPalette.gold.opacity(0.5)).frame(width: 46, height: 1)
            Rectangle().fill(HogwartsPalette.gold).frame(width: 5, height: 5).rotationEffect(.degrees(45))
            Rectangle().fill(HogwartsPalette.gold.opacity(0.5)).frame(width: 46, height: 1)
        }
    }

    private var spellPicker: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SpoilerShowcaseOverlay.spells) { item in
                        chip(for: item)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, -20)
            .mask {
                // Chips slide under a soft edge instead of a hard cut.
                HStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                        .frame(width: 24)
                    Color.black
                    LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: 24)
                }
            }
            .onChange(of: spell) { value in
                withAnimation(spellSpring) {
                    proxy.scrollTo(value, anchor: .center)
                }
            }
        }
    }

    private func chip(for item: SpoilerShowcaseOverlay) -> some View {
        let isSelected = item == spell
        return Button {
            // Every tap casts again: conceal, and move to the next house.
            withAnimation(spellSpring) {
                spell = item
                house = house.next
                generation += 1
            }
        } label: {
            Label(item.title, systemImage: item.symbol)
                .font(.custom(HogwartsFont.caps, size: 12))
                .foregroundStyle(isSelected ? HogwartsPalette.leather : HogwartsPalette.parchment)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(LinearGradient(
                                colors: [HogwartsPalette.gold, HogwartsPalette.goldDeep],
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                            .shadow(color: HogwartsPalette.gold.opacity(0.6), radius: 12)
                            .matchedGeometryEffect(id: "selected-spell", in: selection)
                    } else {
                        Capsule()
                            .fill(HogwartsPalette.parchment.opacity(0.08))
                            .overlay(Capsule().strokeBorder(HogwartsPalette.gold.opacity(0.35)))
                    }
                }
        }
        .buttonStyle(.plain)
        .id(item)
        .accessibilityIdentifier("spell-\(item.rawValue)")
    }

    /// Each spell has its own page, so a new spell conceals on its own; a
    /// repeated tap re-hides the same page by toggling a trailing newline,
    /// which renders identically, without rebuilding the text view.
    private var concealSuffix: String {
        generation.isMultiple(of: 2) ? "" : "\n"
    }

    private var page: some View {
        EnrichedMarkdownText(HogwartsPages.markdown(for: spell) + concealSuffix, flags: Md4cFlags(highlight: true))
            .markdownTheme(spellbookTheme(accent: house.accent))
            .markdownSpoilerOverlay(spell.provider)
            .markdownSelectable(false)
            .padding(.horizontal, 22)
            .padding(.top, 22)
            // The text view ends with the closer's margin and an empty line
            // for the trailing newline; pull the frame up over that band.
            .padding(.bottom, -18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                // Solid parchment: the opaque overlays match it exactly. The
                // shadow stays on the shape so it never tints the text view.
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(HogwartsPalette.parchment)
                    .shadow(color: .black.opacity(0.6), radius: 24, y: 14)
                    .overlay {
                        AgedPaper()
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
            }
            .overlay {
                ParchmentFrame(accent: house.accent)
            }
            .overlay(alignment: .topTrailing) {
                WaxSeal(color: HogwartsPalette.wax)
                    .offset(x: 10, y: -12)
            }
    }

    private var footer: some View {
        Text("I solemnly swear that I am up to no good.")
            .font(.custom(HogwartsFont.bodyItalic, size: 18))
            .foregroundStyle(HogwartsPalette.gold.opacity(0.85))
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
    }

    private var snippet: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(HogwartsPalette.gold)
                .padding(.top, 1)

            // One Text for both lines, so a long provider name scales them together.
            Text("EnrichedMarkdownText(markdown)\n  " + spell.snippet)
                .contentTransition(.numericText())
                .animation(.default, value: spell)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                .lineSpacing(2)
            .foregroundStyle(HogwartsPalette.parchment.opacity(0.9))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HogwartsPalette.leather.opacity(0.55), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(HogwartsPalette.gold.opacity(0.3)))
    }
}

// MARK: - Page dressing

/// Faint darkened corners, so the page reads as old paper. They stay in
/// the corners, clear of the text, where the spoiler overlays and the
/// blockquote must match the plain parchment exactly.
private struct AgedPaper: View {
    private struct Stain {
        let across: Double
        let down: Double
        let radius: Double
        let strength: Double
    }

    private static let stains = [
        Stain(across: 0, down: 0, radius: 0.22, strength: 0.16),
        Stain(across: 1, down: 0, radius: 0.16, strength: 0.1),
        Stain(across: 0, down: 1, radius: 0.18, strength: 0.12),
        Stain(across: 1, down: 1, radius: 0.24, strength: 0.18)
    ]

    var body: some View {
        Canvas { context, size in
            let stain = Color(red: 0.55, green: 0.38, blue: 0.18)
            for spot in Self.stains {
                let (across, down, radius, strength) = (spot.across, spot.down, spot.radius, spot.strength)
                let center = CGPoint(x: size.width * across, y: size.height * down)
                let reach = min(size.width, size.height) * radius
                context.fill(
                    Path(ellipseIn: CGRect(x: center.x - reach, y: center.y - reach, width: reach * 2, height: reach * 2)),
                    with: .radialGradient(
                        Gradient(colors: [stain.opacity(strength), stain.opacity(0)]),
                        center: center, startRadius: 0, endRadius: reach
                    )
                )
            }
        }
        .allowsHitTesting(false)
    }
}

/// A double rule around the page in the house color and gold, with small
/// diamonds at the corners.
private struct ParchmentFrame: View {
    let accent: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(accent.opacity(0.85), lineWidth: 3)
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .strokeBorder(HogwartsPalette.goldDeep.opacity(0.9), lineWidth: 1)
                .padding(6)
            ForEach(0..<4, id: \.self) { corner in
                Rectangle()
                    .fill(HogwartsPalette.gold)
                    .frame(width: 6, height: 6)
                    .rotationEffect(.degrees(45))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment(for: corner))
                    .padding(3)
            }
        }
        .allowsHitTesting(false)
    }

    private func alignment(for corner: Int) -> Alignment {
        [.topLeading, .topTrailing, .bottomLeading, .bottomTrailing][corner]
    }
}

/// A wax seal stamped with an H.
private struct WaxSeal: View {
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [color.opacity(0.95), color.opacity(0.7)], center: .center, startRadius: 0, endRadius: 18))
                .frame(width: 34, height: 34)
                .shadow(color: .black.opacity(0.45), radius: 4, y: 2)
            Circle()
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                .frame(width: 26, height: 26)
            Text("H")
                .font(.custom(HogwartsFont.display, size: 15))
                .foregroundStyle(Color.white.opacity(0.75))
        }
        .allowsHitTesting(false)
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
        HogwartsScreen()
            .immersiveNavigationBar()
    }
}
