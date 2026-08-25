import Foundation
import UIKit

final class AsyncRenderCoordinator {
    var blockAsyncRender = false

    private let queue: DispatchQueue
    private var currentRenderId: UInt = 0

    init(queueLabel: String = "com.swmansion.enriched.markdown.render") {
        queue = DispatchQueue(label: queueLabel)
    }

    func scheduleRender(
        _ render: @escaping () -> NSAttributedString?,
        apply: @escaping (NSAttributedString) -> Void
    ) {
        if blockAsyncRender {
            return
        }

        currentRenderId += 1
        let renderId = currentRenderId

        queue.async { [weak self] in
            guard let result = render() else { return }

            DispatchQueue.main.async {
                guard let self, renderId == self.currentRenderId else { return }
                apply(result)
            }
        }
    }

    func invalidate() {
        currentRenderId += 1
    }
}
