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

    private let coordinator = AsyncRenderCoordinator()

    func schedule(
        markdown: String,
        config: MarkdownStyleConfig,
        flags: Md4cFlags = .commonMark,
        imageRequestHeaders: [String: String] = [:]
    ) {
        if isBlank(markdown) {
            attributedText = NSAttributedString()
            source = nil
            baseMarkdown = nil
            currentMarkdown = nil
            return
        }
        let resolved = markdown == baseMarkdown ? (currentMarkdown ?? markdown) : markdown
        baseMarkdown = markdown
        currentMarkdown = resolved

        coordinator.scheduleRender {
            MarkdownRenderer.render(
                resolved,
                config: config,
                flags: flags,
                imageRequestHeaders: imageRequestHeaders
            )
        } apply: { [weak self] result in
            self?.attributedText = result
            self?.source = RenderedSource(markdown: resolved, flags: flags)
        }
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
