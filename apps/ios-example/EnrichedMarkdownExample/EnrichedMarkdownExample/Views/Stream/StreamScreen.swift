import EnrichedMarkdown
import EnrichedMarkdownLaTeX
import EnrichedMarkdownStreaming
import EnrichedMarkdownSyntaxHighlighting
import SwiftUI

private let streamSource = #"""
# Streaming markdown

This answer arrives a few characters at a time, the way a language model writes one. Unfinished **bold**, *italic*, `code` and [links](https://swmansion.com) never show their syntax, and every new piece of text fades in.

## Blocks that wait

A table renders row by row once its header and delimiter row are in:

| Area | Behavior |
| --- | --- |
| Text | Streams and fades in |
| Tables | Rows appear as they complete |
| Code | Streams line by line, highlighted once closed |
| Math | Shown once the closing `$$` arrives |

Code streams in under its header, and the copy button turns on when the fence closes:

```python
def tokens(answer):
    for word in answer.split():
        yield word + " "
```

Display math is all or nothing:

$$
\int_0^1 x^2 \, dx = \frac{1}{3}
$$

> [!NOTE]
> Finished blocks are rendered once and kept. Only the open tail of the document is parsed again on each update.

- [x] Repair unfinished syntax
- [x] Hold back half-written blocks
- [ ] Ship it

Inline math like $E = mc^2$ waits for its closing dollar too, and prices like 5$ or 3 $ stay text. That is the whole story — *fin*.
"""#

private let tickInterval: TimeInterval = 0.05
private let charactersPerTick: Int = 6

@available(iOS 18.0, *)
private struct StreamTailFollowing: ViewModifier {
    @State private var position = ScrollPosition(edge: .top)

    func body(content: Content) -> some View {
        content
            .scrollPosition($position)
            .onScrollGeometryChange(for: ScrollGeometry.self) { $0 } action: { old, new in
                let wasAtBottom = old.visibleRect.maxY - old.contentInsets.bottom >= old.contentSize.height - 1
                if new.contentSize.height > old.contentSize.height, wasAtBottom {
                    position.scrollTo(edge: .bottom)
                }
            }
    }
}

private extension View {
    @ViewBuilder
    func followsStreamTail() -> some View {
        if #available(iOS 18.0, *) {
            modifier(StreamTailFollowing())
        } else {
            self
        }
    }
}

struct StreamScreen: View {
    // MARK: - Properties

    @State private var cursor: Int = 0
    @State private var isPlaying: Bool = false
    @State private var hidesTables: Bool = false
    @State private var hidesCodeBlocks: Bool = false
    @State private var transition: StreamTransition = .opacity
    @State private var usesScrollablePanels: Bool = true

    private var markdown: String { String(streamSource.prefix(cursor)) }
    private var isComplete: Bool { cursor >= streamSource.count }

    // MARK: - Views

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Hide tables until complete", isOn: $hidesTables)
                    .accessibilityIdentifier("stream-hide-tables-toggle")
                Toggle("Hide code blocks until complete", isOn: $hidesCodeBlocks)
                    .accessibilityIdentifier("stream-hide-code-blocks-toggle")
                Picker("Transition", selection: $transition) {
                    ForEach(StreamTransition.allCases) { transition in
                        Text(transition.rawValue).tag(transition)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("stream-transition-picker")
                Toggle("Scrollable code panels", isOn: $usesScrollablePanels)
                    .accessibilityIdentifier("stream-scrollable-panels-toggle")

                EnrichedMarkdownText(markdown, options: MarkdownParsingOptions(admonitions: true))
                    .markdownStreaming(
                        !isComplete,
                        tables: hidesTables ? .hidden : .progressive,
                        codeBlocks: hidesCodeBlocks ? .hidden : .progressive,
                        transition: transition.transition
                    )
                    .markdownLaTeX()
                    .markdownSyntaxHighlighting()
                    .markdownCodeBlockLayout(usesScrollablePanels ? .scrollable : .wrapping)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .followsStreamTail()
        .safeAreaInset(edge: .top, spacing: 0) {
            controls
        }
        .background(Color(UIColor.systemBackground))
        .task(id: isPlaying) {
            guard isPlaying else { return }
            while !Task.isCancelled, !isComplete {
                try? await Task.sleep(nanoseconds: UInt64(tickInterval * 1_000_000_000))
                guard !Task.isCancelled else { return }
                step()
            }
            isPlaying = false
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                PlaygroundButton(
                    label: isPlaying ? "Pause" : (isComplete ? "Replay" : "Start"),
                    accessibilityId: "stream-play-button",
                    isActive: isPlaying
                ) {
                    if isComplete {
                        cursor = 0
                    }
                    isPlaying.toggle()
                }
                PlaygroundButton(label: "Step", accessibilityId: "stream-step-button") {
                    step()
                }
                PlaygroundButton(label: "Reset", accessibilityId: "stream-reset-button") {
                    isPlaying = false
                    cursor = 0
                }
            }

            Text("\(cursor)/\(streamSource.count) characters")
                .font(.footnote)
                .foregroundStyle(Color.secondaryText)
                .accessibilityIdentifier("stream-progress")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.systemBackground))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    // MARK: - Methods

    private func step() {
        cursor = min(cursor + charactersPerTick, streamSource.count)
    }
}

// MARK: -

#Preview {
    StreamScreen()
}
