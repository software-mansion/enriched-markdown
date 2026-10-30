import EnrichedMarkdown
import SwiftUI

private let sampleLinksMarkdown = """
## Mentions

Ask [@alice](user://alice) or [@bob](user://bob) in [#forest-watch](channel://forest-watch), \
or read the [field guide](https://example.com/forests/guide).

Two in a row: [@alice](user://alice)[@bob](user://bob). A long one wraps: \
[@a-very-long-handle-that-runs-onto-the-next-line-in-portrait](user://long) end.

## Avatars

Only [![](https://picsum.photos/id/1/64/64)](user://avatar), \
with a name [![](https://picsum.photos/id/64/64/64) @carol](user://carol).

## Around other formatting

==A highlight around [@alice](user://alice) and [#forest-watch](channel://forest-watch).== \
Inline code inside: [`@dave` profile](user://dave), and **bold [@erin](user://erin)**.

## In a table

| Who | Where |
| --- | --- |
| [@alice](user://alice) | [#forest-watch](channel://forest-watch) |
| [@bob](user://bob) | [#wildlife](channel://wildlife) |
"""

private enum MentionStyle: String, CaseIterable, Identifiable {
    case chip = "Chip"
    case fill = "Fill"
    case outline = "Outline"
    case plain = "Plain"

    var id: String { rawValue }
}

private enum MentionTint: String, CaseIterable, Identifiable {
    case indigo = "Indigo"
    case navy = "Navy"
    case teal = "Teal"
    case pink = "Pink"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .indigo: return .tileIndigo
        case .navy: return .brandNavy
        case .teal: return .tileTeal
        case .pink: return .tilePink
        }
    }
}

struct LinksScreen: View {
    @State private var style: MentionStyle = .chip
    @State private var mentionTint: MentionTint = .indigo
    @State private var borderWidth: Double = 1
    @State private var cornerRadius: Double = 4
    @State private var lineHeight: Double = 26
    @State private var underlinesLinks: Bool = true
    @State private var pressedLink: URL?
    @State private var linkAlertVisible: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Mention style", selection: $style) {
                    ForEach(MentionStyle.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("links-style-picker")

                Picker("Tint", selection: $mentionTint) {
                    ForEach(MentionTint.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("links-tint-picker")

                slider("Border", value: $borderWidth, in: 0.5...6, step: 0.5, id: "links-border-slider")
                slider("Radius", value: $cornerRadius, in: 0...12, step: 1, id: "links-radius-slider")
                slider("Line height", value: $lineHeight, in: 20...40, step: 2, id: "links-line-height-slider")

                Toggle("Underline ordinary links", isOn: $underlinesLinks)
                    .accessibilityIdentifier("links-underline-toggle")

                EnrichedMarkdownText(sampleLinksMarkdown, options: MarkdownParsingOptions(highlight: true))
                    .markdownTheme(theme)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.openURL, OpenURLAction { url in
                        pressedLink = url
                        linkAlertVisible = true
                        return .handled
                    })
            }
            .padding(16)
        }
        .background(Color(UIColor.systemBackground))
        .accessibilityIdentifier("links-screen")
        .alert("Link pressed", isPresented: $linkAlertVisible, presenting: pressedLink) { _ in
            Button("OK", role: .cancel) {}
        } message: { url in
            Text(url.absoluteString)
        }
    }

    private var theme: MarkdownTheme {
        MarkdownTheme {
            Paragraph().lineHeight(lineHeight)
            InlineImage().size(24)
            EnrichedMarkdown.Link().underline(underlinesLinks)
            mention(matching: "^user:", color: mentionTint.color)
            mention(matching: "^channel:", color: mentionTint.color)
        }
    }

    private func mention(matching pattern: String, color: Color) -> EnrichedMarkdown.Link {
        let link = EnrichedMarkdown.Link(matching: pattern).foregroundStyle(color).underline(false)
        switch style {
        case .chip:
            return link.background(color.opacity(0.15)).border(color, width: borderWidth).cornerRadius(cornerRadius)
        case .fill:
            return link.background(color.opacity(0.15)).cornerRadius(cornerRadius)
        case .outline:
            return link.border(color, width: borderWidth).cornerRadius(cornerRadius)
        case .plain:
            return EnrichedMarkdown.Link(matching: pattern).foregroundStyle(color)
        }
    }

    private func slider(
        _ label: String,
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        step: Double,
        id: String
    ) -> some View {
        HStack(spacing: 12) {
            Text("\(label) \(String(format: "%g", value.wrappedValue)) pt")
                .font(.subheadline)
                .frame(width: 130, alignment: .leading)
            Slider(value: value, in: range, step: step)
                .accessibilityIdentifier(id)
        }
    }
}

// MARK: -

#Preview {
    LinksScreen()
}
