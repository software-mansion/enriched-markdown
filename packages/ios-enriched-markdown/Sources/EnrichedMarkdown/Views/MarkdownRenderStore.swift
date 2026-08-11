import SwiftUI
import UIKit

@MainActor
final class MarkdownRenderStore: ObservableObject {
    @Published private(set) var attributedText = NSAttributedString()
    // Published together with `attributedText` so consumers never pair a new
    // markdown string with a stale render result.
    @Published private(set) var sourceMarkdown: String?

    private let coordinator = AsyncRenderCoordinator()

    func schedule(
        markdown: String,
        config: MarkdownStyleConfig,
        flags: Md4cFlags = .commonMark
    ) {
        if isBlank(markdown) {
            attributedText = NSAttributedString()
            sourceMarkdown = nil
            return
        }

        coordinator.scheduleRender {
            MarkdownRenderer.render(markdown, config: config, flags: flags)
        } apply: { [weak self] result in
            self?.attributedText = result
            self?.sourceMarkdown = markdown
        }
    }

    func invalidate() {
        coordinator.invalidate()
    }

    private func isBlank(_ markdown: String) -> Bool {
        markdown.isEmpty || markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
