import SwiftUI
import UIKit

@MainActor
final class MarkdownRenderStore: ObservableObject {
    @Published private(set) var attributedText = NSAttributedString()
    // Published together with `attributedText` so consumers never pair a new
    // markdown string with a stale render result.
    @Published private(set) var sourceMarkdown: String?

    /// The caller's markdown as last scheduled, before any checkbox toggle.
    /// A schedule for the same base re-renders `currentMarkdown` instead, so
    /// toggles survive style/flag re-renders and re-appearing views; a new
    /// base always wins.
    private var baseMarkdown: String?

    /// `baseMarkdown` plus any checkbox toggles applied since, tracked
    /// synchronously (unlike `sourceMarkdown`, which waits for the render).
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
            sourceMarkdown = nil
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
            self?.sourceMarkdown = resolved
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
        if let source = currentMarkdown {
            let updatedSource = TaskListInteraction.togglingSource(source, index: index, checked: checked)
            currentMarkdown = updatedSource
            if sourceMarkdown != nil {
                sourceMarkdown = updatedSource
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
