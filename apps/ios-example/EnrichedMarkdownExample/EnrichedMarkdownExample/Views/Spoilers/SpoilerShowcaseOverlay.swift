import EnrichedMarkdown
import SwiftUI

/// Every overlay the Spoilers screen can switch between: the library's
/// default, the blur sample from the package README, and twenty-four effects
/// written for this demo. Each one is a `SpoilerOverlayView` subclass behind
/// a `SpoilerOverlayProvider`.
enum SpoilerShowcaseOverlay: String, CaseIterable, Identifiable {
    case `default`
    case blur
    case pixelate
    case decode
    case liquid
    case scatter
    case river
    case reels
    case glass
    case revelio
    case map
    case snitch
    case howler
    case lumos
    case patronus
    case fiendfyre
    case portkey
    case timeTurner = "time-turner"
    case sortingHat = "sorting-hat"
    case floo
    case apparition
    case feathers
    case riddikulus
    case expelliarmus
    case glitch
    case shimmer

    var id: Self { self }

    /// The spells the Hogwarts screen casts, in the order it shows them.
    static let spells: [SpoilerShowcaseOverlay] = [
        .revelio, .expelliarmus, .snitch, .map, .lumos, .patronus, .floo, .howler,
        .riddikulus, .apparition, .fiendfyre, .timeTurner, .sortingHat, .portkey, .feathers
    ]

    var title: String {
        switch self {
        case .default: return "Default"
        case .blur: return "Blur"
        case .pixelate: return "Pixelate"
        case .decode: return "Decode"
        case .liquid: return "Liquid"
        case .scatter: return "Scatter"
        case .river: return "River"
        case .reels: return "Reels"
        case .glass: return "Glass"
        case .revelio: return "Revelio"
        case .map: return "Map"
        case .snitch: return "Snitch"
        case .howler: return "Howler"
        case .lumos: return "Lumos"
        case .patronus: return "Patronus"
        case .fiendfyre: return "Fiendfyre"
        case .portkey: return "Portkey"
        case .timeTurner: return "Time-Turner"
        case .sortingHat: return "Sorting Hat"
        case .floo: return "Floo"
        case .apparition: return "Apparition"
        case .feathers: return "Feathers"
        case .riddikulus: return "Riddikulus"
        case .expelliarmus: return "Expelliarmus"
        case .glitch: return "Glitch"
        case .shimmer: return "Shimmer"
        }
    }

    var symbol: String {
        switch self {
        case .default: return "sparkles"
        case .blur: return "cloud.fog.fill"
        case .pixelate: return "square.grid.3x3.fill"
        case .decode: return "terminal.fill"
        case .liquid: return "drop.fill"
        case .scatter: return "wind"
        case .river: return "water.waves"
        case .reels: return "rectangle.split.1x2"
        case .glass: return "hand.draw.fill"
        case .revelio: return "wand.and.rays"
        case .map: return "map.fill"
        case .snitch: return "circle.circle.fill"
        case .howler: return "envelope.open.fill"
        case .lumos: return "flashlight.on.fill"
        case .patronus: return "pawprint.fill"
        case .fiendfyre: return "flame.fill"
        case .portkey: return "arrow.triangle.2.circlepath"
        case .timeTurner: return "hourglass"
        case .sortingHat: return "graduationcap.fill"
        case .floo: return "flame"
        case .apparition: return "smoke.fill"
        case .feathers: return "bird.fill"
        case .riddikulus: return "face.smiling.inverse"
        case .expelliarmus: return "bolt.horizontal.fill"
        case .glitch: return "waveform.path"
        case .shimmer: return "wand.and.stars"
        }
    }

    /// Short enough for one line on a phone, so the header keeps its height
    /// and the card below does not shift when the effect changes.
    var tagline: String {
        switch self {
        case .default: return "The built-in particle field, no code needed."
        case .blur: return "Frosted glass drawn from the hidden text."
        case .pixelate: return "An 8-bit mosaic that sharpens into place."
        case .decode: return "Cipher glyphs resolve into the real words."
        case .liquid: return "Molten letters that cool into place."
        case .scatter: return "Dust that flies back into words."
        case .river: return "A current of fragments pulled back into words."
        case .reels: return "Split-flap reels that lock in one by one."
        case .glass: return "Frosted glass wiped clear by hand."
        case .revelio: return "A wand sweep that conjures words from sparks."
        case .map: return "Footprints wander, then ink seeps into words."
        case .snitch: return "A golden Snitch that draws the words in its wake."
        case .howler: return "A red envelope that bursts open and shouts."
        case .lumos: return "Light blooms from an ember in the dark."
        case .patronus: return "Silver mist that streams away into words."
        case .fiendfyre: return "Flames burn across, leaving glowing words."
        case .portkey: return "A twisting helix that unwinds into words."
        case .timeTurner: return "Nested rings that unwind backwards into words."
        case .sortingHat: return "Muttering glyphs that decide on a house."
        case .floo: return "Green fire the words tumble out of."
        case .apparition: return "Whirling streaks that crack into place."
        case .feathers: return "Owl feathers a gust blows off the words."
        case .riddikulus: return "A boggart that pops into laughing confetti."
        case .expelliarmus: return "A red bolt that blasts the grip off the words."
        case .glitch: return "A torn signal that snaps into focus."
        case .shimmer: return "A glossy bar that pops open on reveal."
        }
    }

    /// The one line an app writes to get this effect.
    var snippet: String {
        switch self {
        case .default: return ".markdownSpoilerOverlay(.particles(density: 12))"
        case .blur: return ".markdownSpoilerOverlay(BlurOverlayProvider())"
        case .pixelate: return ".markdownSpoilerOverlay(PixelateOverlayProvider())"
        case .decode: return ".markdownSpoilerOverlay(DecodeOverlayProvider())"
        case .liquid: return ".markdownSpoilerOverlay(LiquidOverlayProvider())"
        case .scatter: return ".markdownSpoilerOverlay(ScatterOverlayProvider())"
        case .river: return ".markdownSpoilerOverlay(RiverOverlayProvider())"
        case .reels: return ".markdownSpoilerOverlay(ReelsOverlayProvider())"
        case .glass: return ".markdownSpoilerOverlay(GlassOverlayProvider())"
        case .revelio: return ".markdownSpoilerOverlay(RevelioOverlayProvider())"
        case .map: return ".markdownSpoilerOverlay(MapOverlayProvider())"
        case .snitch: return ".markdownSpoilerOverlay(SnitchOverlayProvider())"
        case .howler: return ".markdownSpoilerOverlay(HowlerOverlayProvider())"
        case .lumos: return ".markdownSpoilerOverlay(LumosOverlayProvider())"
        case .patronus: return ".markdownSpoilerOverlay(PatronusOverlayProvider())"
        case .fiendfyre: return ".markdownSpoilerOverlay(FiendfyreOverlayProvider())"
        case .portkey: return ".markdownSpoilerOverlay(PortkeyOverlayProvider())"
        case .timeTurner: return ".markdownSpoilerOverlay(TimeTurnerOverlayProvider())"
        case .sortingHat: return ".markdownSpoilerOverlay(SortingHatOverlayProvider())"
        case .floo: return ".markdownSpoilerOverlay(FlooOverlayProvider())"
        case .apparition: return ".markdownSpoilerOverlay(ApparitionOverlayProvider())"
        case .feathers: return ".markdownSpoilerOverlay(FeathersOverlayProvider())"
        case .riddikulus: return ".markdownSpoilerOverlay(RiddikulusOverlayProvider())"
        case .expelliarmus: return ".markdownSpoilerOverlay(ExpelliarmusOverlayProvider())"
        case .glitch: return ".markdownSpoilerOverlay(GlitchOverlayProvider())"
        case .shimmer: return ".markdownSpoilerOverlay(ShimmerOverlayProvider())"
        }
    }

    var provider: any SpoilerOverlayProvider {
        switch self {
        case .default: return .particles(density: 12)
        case .blur: return BlurOverlayProvider()
        case .pixelate: return PixelateOverlayProvider()
        case .decode: return DecodeOverlayProvider()
        case .liquid: return LiquidOverlayProvider()
        case .scatter: return ScatterOverlayProvider()
        case .river: return RiverOverlayProvider()
        case .reels: return ReelsOverlayProvider()
        case .glass: return GlassOverlayProvider()
        case .revelio: return RevelioOverlayProvider()
        case .map: return MapOverlayProvider()
        case .snitch: return SnitchOverlayProvider()
        case .howler: return HowlerOverlayProvider()
        case .lumos: return LumosOverlayProvider()
        case .patronus: return PatronusOverlayProvider()
        case .fiendfyre: return FiendfyreOverlayProvider()
        case .portkey: return PortkeyOverlayProvider()
        case .timeTurner: return TimeTurnerOverlayProvider()
        case .sortingHat: return SortingHatOverlayProvider()
        case .floo: return FlooOverlayProvider()
        case .apparition: return ApparitionOverlayProvider()
        case .feathers: return FeathersOverlayProvider()
        case .riddikulus: return RiddikulusOverlayProvider()
        case .expelliarmus: return ExpelliarmusOverlayProvider()
        case .glitch: return GlitchOverlayProvider()
        case .shimmer: return ShimmerOverlayProvider()
        }
    }
}

/// Tints fed to `Spoiler().color`; each effect tap moves to the next one.
enum SpoilerShowcaseAccent: CaseIterable, Identifiable {
    case mint
    case sky
    case coral
    case violet
    case gold

    var id: Self { self }

    var next: Self {
        let all = Self.allCases
        let index = all.firstIndex(of: self) ?? 0
        return all[(index + 1) % all.count]
    }

    var color: Color {
        switch self {
        case .mint: return .brandMint
        case .sky: return Color(red: 96 / 255, green: 186 / 255, blue: 255 / 255)
        case .coral: return Color(red: 255 / 255, green: 112 / 255, blue: 112 / 255)
        case .violet: return Color(red: 180 / 255, green: 140 / 255, blue: 255 / 255)
        case .gold: return Color(red: 255 / 255, green: 206 / 255, blue: 92 / 255)
        }
    }
}
