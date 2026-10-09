import Foundation
import UIKit
import os

final class AsyncRenderCoordinator {
    var blockAsyncRender = false

    private let queue: DispatchQueue
    /// The newest schedule's id; a render checks it before starting, so one
    /// superseded while queued is skipped rather than rendered and dropped.
    private let latestRenderId = OSAllocatedUnfairLock<UInt>(initialState: 0)

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

        let renderId = latestRenderId.withLock { id -> UInt in
            id += 1
            return id
        }

        queue.async { [weak self] in
            guard let self, renderId == self.latestRenderId.withLock({ $0 }) else { return }
            guard let result = render() else { return }

            DispatchQueue.main.async {
                guard renderId == self.latestRenderId.withLock({ $0 }) else { return }
                apply(result)
            }
        }
    }

    func invalidate() {
        latestRenderId.withLock { $0 += 1 }
    }
}
