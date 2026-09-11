import SwiftUI
import UIKit

/// A rendered document's original markdown paired with the parse flags it
/// was rendered with — one value, so consumers can never pair a source with
/// the wrong flags.
struct RenderedSource: Equatable {
    let markdown: String
    let flags: Md4cFlags
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

    func schedule(
        markdown: String,
        config: MarkdownStyleConfig,
        flags: Md4cFlags = .commonMark,
        imageRequestHeaders: [String: String] = [:],
        plugins: [any MarkdownRenderPlugin] = []
    ) {
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
        // render adjusts the flags itself; the source keeps the adjusted ones for copying.
        let effectiveFlags = MarkdownRenderer.effectiveFlags(flags, plugins: plugins)

        coordinator.scheduleRender {
            MarkdownRenderer.render(
                resolved,
                config: config,
                flags: flags,
                imageRequestHeaders: imageRequestHeaders,
                plugins: plugins
            )
        } apply: { [weak self] result in
            guard let self else { return }
            attributedText = SpoilerInteraction.revealing(in: result, ordinals: revealedSpoilers) ?? result
            source = RenderedSource(markdown: resolved, flags: effectiveFlags)
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
    func applyTaskListToggle(index: Int, checked: Bool, config: MarkdownStyleConfig) {
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
            if let flags = source?.flags {
                source = RenderedSource(markdown: updatedSource, flags: flags)
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
