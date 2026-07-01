import SwiftUI
import UIKit

@MainActor
final class MarkdownRenderStore: ObservableObject {
    @Published private(set) var attributedText = NSAttributedString()

    private let coordinator = AsyncRenderCoordinator()

    func schedule(
        markdown: String,
        config: MarkdownStyleConfig,
        flags: Md4cFlags = .commonMark
    ) {
        if isBlank(markdown) {
            attributedText = NSAttributedString()
            return
        }

        coordinator.scheduleRender {
            MarkdownRenderer.render(markdown, config: config, flags: flags)
        } apply: { [weak self] result in
            self?.attributedText = result
        }
    }

    func invalidate() {
        coordinator.invalidate()
    }

    private func isBlank(_ markdown: String) -> Bool {
        markdown.isEmpty || markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
