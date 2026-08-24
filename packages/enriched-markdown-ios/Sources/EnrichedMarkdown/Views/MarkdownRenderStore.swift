import SwiftUI
import UIKit

@MainActor
final class MarkdownRenderStore: ObservableObject {
    @Published private(set) var segments = MarkdownSegmentRenderer.empty
    // Published together with `segments` so consumers never pair a new
    // markdown string with a stale render result.
    @Published private(set) var sourceMarkdown: String?

    private let coordinator = AsyncRenderCoordinator()

    func schedule(
        markdown: String,
        config: MarkdownStyleConfig,
        flags: Md4cFlags = .commonMark,
        imageRequestHeaders: [String: String] = [:]
    ) {
        if isBlank(markdown) {
            segments = MarkdownSegmentRenderer.empty
            sourceMarkdown = nil
            return
        }

        coordinator.scheduleRender {
            MarkdownSegmentRenderer.renderSegments(
                markdown,
                config: config,
                flags: flags,
                imageRequestHeaders: imageRequestHeaders
            )
        } apply: { [weak self] result in
            self?.segments = result
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
