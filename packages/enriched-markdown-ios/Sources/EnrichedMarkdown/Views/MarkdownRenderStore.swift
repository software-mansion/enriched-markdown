import SwiftUI
import UIKit

/// A rendered document's original markdown paired with the parse options it
/// was rendered with — one value, so consumers can never pair a source with
/// the wrong options.
struct RenderedSource: Equatable {
    let markdown: String
    let options: MarkdownParsingOptions
}

/// What a render depends on, as one value so a change to any of it
/// schedules exactly one re-render.
package struct MarkdownRenderInputs: Equatable {
    package var markdown: String
    package var config: MarkdownStyleConfiguration
    package var options: MarkdownParsingOptions
    package var imageRequestHeaders: [String: String]
    package var plugins: RenderPluginList
    package var writingDirection: MarkdownWritingDirection
    package var layoutDirection: LayoutDirection
    package var codeBlockLayout: MarkdownCodeBlockLayout
    package var streaming: AnyMarkdownStreamingPlugin?

    package init(
        markdown: String,
        config: MarkdownStyleConfiguration,
        options: MarkdownParsingOptions = .commonMark,
        imageRequestHeaders: [String: String] = [:],
        plugins: RenderPluginList = RenderPluginList(),
        writingDirection: MarkdownWritingDirection = .firstStrong,
        layoutDirection: LayoutDirection = .leftToRight,
        codeBlockLayout: MarkdownCodeBlockLayout = .wrapping,
        streaming: AnyMarkdownStreamingPlugin? = nil
    ) {
        self.markdown = markdown
        self.config = config
        self.options = options
        self.imageRequestHeaders = imageRequestHeaders
        self.plugins = plugins
        self.writingDirection = writingDirection
        self.layoutDirection = layoutDirection
        self.codeBlockLayout = codeBlockLayout
        self.streaming = streaming
    }

    package var sessionKey: MarkdownRenderInputs {
        var key = self
        key.markdown = ""
        key.streaming = nil
        return key
    }
}

package struct RenderPluginList: Equatable {
    package var values: [any MarkdownRenderPlugin]

    package init(values: [any MarkdownRenderPlugin] = []) {
        self.values = values
    }

    package static func == (lhs: RenderPluginList, rhs: RenderPluginList) -> Bool {
        lhs.values.elementsEqual(rhs.values) { type(of: $0) == type(of: $1) }
    }
}

@MainActor
final class MarkdownRenderStore: ObservableObject {
    @Published private(set) var attributedText = NSAttributedString()
    // Published together with `attributedText` so consumers never pair a new
    // source with a stale render result.
    @Published private(set) var source: RenderedSource?
    @Published private(set) var lineage: StreamingLineage?

    /// The caller's markdown as last scheduled. A schedule for the same base
    /// re-renders `currentMarkdown` instead — toggles survive style/flag
    /// re-renders — while a new base always wins.
    private var baseMarkdown: String?

    /// `baseMarkdown` plus any checkbox toggles applied since, tracked
    /// synchronously (unlike `source`, which waits for the render).
    private var currentMarkdown: String?

    /// Ordinals (see `SpoilerInteraction.spoilerRanges`) of spoilers revealed
    /// since the markdown last changed. Re-applied after a re-render of the
    /// same source (a theme change, say) so a revealed spoiler does not snap
    /// shut; a new source starts concealed.
    private var revealedSpoilers: Set<Int> = []

    private let coordinator = AsyncRenderCoordinator()

    private var streamingSession: (any MarkdownStreamingSession)?

    func schedule(_ inputs: MarkdownRenderInputs) {
        let markdown = inputs.markdown
        if isBlank(markdown) {
            coordinator.invalidate()
            attributedText = NSAttributedString()
            source = nil
            lineage = nil
            baseMarkdown = nil
            currentMarkdown = nil
            revealedSpoilers = []
            if inputs.streaming == nil {
                streamingSession = nil
            }
            return
        }
        let resolved = markdown == baseMarkdown ? (currentMarkdown ?? markdown) : markdown
        if markdown != baseMarkdown {
            revealedSpoilers = []
        }
        baseMarkdown = markdown
        currentMarkdown = resolved
        // render adjusts the options itself; the source keeps the adjusted ones for copying.
        let effectiveOptions = MarkdownRenderer.effectiveParsingOptions(inputs.options, plugins: inputs.plugins.values)
        let session = streamingSession.flatMap { $0.key == inputs.sessionKey ? $0 : nil }

        if let streaming = inputs.streaming {
            let session = session ?? streaming.makeSession(inputs: inputs)
            streamingSession = session
            coordinator.scheduleRender {
                session.render(resolved, plugin: streaming)
            } apply: { [weak self] result in
                self?.publish(result, options: effectiveOptions)
            }
            return
        }

        streamingSession = nil
        let endedSession = session?.id
        coordinator.scheduleRender {
            MarkdownRenderer.render(resolved, inputs: inputs)
        } apply: { [weak self] result in
            guard let self else { return }
            attributedText = SpoilerInteraction.revealing(in: result, ordinals: revealedSpoilers) ?? result
            source = RenderedSource(markdown: resolved, options: effectiveOptions)
            lineage = endedSession.map { StreamingLineage(session: $0, stableLength: 0) }
        }
    }

    private func publish(_ result: StreamingRenderResult, options: MarkdownParsingOptions) {
        guard result.source != source?.markdown || result.lineage.session != lineage?.session else { return }
        if revealedSpoilers.isEmpty {
            attributedText = result.text
            lineage = result.lineage
        } else {
            attributedText = SpoilerInteraction.revealing(in: result.text, ordinals: revealedSpoilers) ?? result.text
            lineage = nil
        }
        source = RenderedSource(markdown: result.source, options: options)
    }

    /// Shows the concealed spoiler covering `range` in place.
    func revealSpoiler(in range: NSRange) {
        guard let ordinal = SpoilerInteraction.spoilerRanges(in: attributedText)
            .firstIndex(where: { NSLocationInRange(range.location, $0) }),
            let revealed = SpoilerInteraction.revealing(in: attributedText, ordinals: [ordinal])
        else { return }
        attributedText = revealed
        lineage = nil
        revealedSpoilers.insert(ordinal)
    }

    /// Flips one task item's checked state in place: rendered text and
    /// tracked source, no re-parse. Drops any in-flight render so a stale
    /// result can't revert the toggle.
    func applyTaskListToggle(index: Int, checked: Bool, config: MarkdownStyleConfiguration) {
        guard let toggled = TaskListInteraction.togglingItem(
            in: attributedText,
            index: index,
            checked: checked,
            config: config
        ) else { return }

        coordinator.invalidate()
        attributedText = toggled
        lineage = nil
        if let markdown = currentMarkdown {
            let updatedSource = TaskListInteraction.togglingSource(markdown, index: index, checked: checked)
            currentMarkdown = updatedSource
            if let options = source?.options {
                source = RenderedSource(markdown: updatedSource, options: options)
            }
        }
    }

    func invalidate() {
        coordinator.invalidate()
    }

    private func isBlank(_ markdown: String) -> Bool {
        markdown.isEmpty || markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

extension UIUserInterfaceLayoutDirection {
    init(_ layoutDirection: LayoutDirection) {
        switch layoutDirection {
        case .rightToLeft: self = .rightToLeft
        case .leftToRight: self = .leftToRight
        @unknown default: self = .leftToRight
        }
    }
}
