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
/// schedules exactly one re-render. Plugins travel alongside: they are
/// not `Equatable`.
struct MarkdownRenderInputs: Equatable {
    var markdown: String
    var config: MarkdownStyleConfiguration
    var options: MarkdownParsingOptions = .commonMark
    var imageRequestHeaders: [String: String] = [:]
    var writingDirection: MarkdownWritingDirection = .firstStrong
    var layoutDirection: LayoutDirection = .leftToRight
}

@MainActor
final class MarkdownRenderStore: ObservableObject {
    @Published private(set) var attributedText = NSAttributedString()
    // Published together with `attributedText` so consumers never pair a new
    // source with a stale render result.
    @Published private(set) var source: RenderedSource?

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

    func schedule(_ inputs: MarkdownRenderInputs, plugins: [any MarkdownRenderPlugin] = []) {
        let markdown = inputs.markdown
        if isBlank(markdown) {
            attributedText = NSAttributedString()
            source = nil
            baseMarkdown = nil
            currentMarkdown = nil
            revealedSpoilers = []
            return
        }
        let resolved = markdown == baseMarkdown ? (currentMarkdown ?? markdown) : markdown
        if markdown != baseMarkdown {
            revealedSpoilers = []
        }
        baseMarkdown = markdown
        currentMarkdown = resolved
        // render adjusts the options itself; the source keeps the adjusted ones for copying.
        let effectiveOptions = MarkdownRenderer.effectiveParsingOptions(inputs.options, plugins: plugins)

        coordinator.scheduleRender {
            MarkdownRenderer.render(
                resolved,
                config: inputs.config,
                options: inputs.options,
                imageRequestHeaders: inputs.imageRequestHeaders,
                plugins: plugins,
                writingDirection: inputs.writingDirection,
                layoutDirection: UIUserInterfaceLayoutDirection(inputs.layoutDirection)
            )
        } apply: { [weak self] result in
            guard let self else { return }
            attributedText = SpoilerInteraction.revealing(in: result, ordinals: revealedSpoilers) ?? result
            source = RenderedSource(markdown: resolved, options: effectiveOptions)
        }
    }

    /// Shows the concealed spoiler covering `range` in place.
    func revealSpoiler(in range: NSRange) {
        guard let ordinal = SpoilerInteraction.spoilerRanges(in: attributedText)
            .firstIndex(where: { NSLocationInRange(range.location, $0) }),
            let revealed = SpoilerInteraction.revealing(in: attributedText, ordinals: [ordinal])
        else { return }
        attributedText = revealed
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

private extension UIUserInterfaceLayoutDirection {
    init(_ layoutDirection: LayoutDirection) {
        switch layoutDirection {
        case .rightToLeft: self = .rightToLeft
        case .leftToRight: self = .leftToRight
        @unknown default: self = .leftToRight
        }
    }
}
