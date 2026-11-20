import EnrichedMarkdown
import UIKit

public protocol MarkdownStreamingTransition: Equatable, Sendable {
    @MainActor
    func animate(_ view: UIView, completion: @escaping () -> Void)
}

public struct OpacityStreamingTransition: MarkdownStreamingTransition {
    public var duration: TimeInterval

    public init(duration: TimeInterval = 0.2) {
        self.duration = duration
    }

    public func animate(_ view: UIView, completion: @escaping () -> Void) {
        view.alpha = 0
        UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
            view.alpha = 1
        } completion: { _ in
            completion()
        }
    }
}

public struct IdentityStreamingTransition: MarkdownStreamingTransition {
    public init() {}

    public func animate(_ view: UIView, completion: @escaping () -> Void) {
        completion()
    }
}

public extension MarkdownStreamingTransition where Self == OpacityStreamingTransition {
    static var opacity: Self { Self() }

    static func opacity(duration: TimeInterval) -> Self {
        Self(duration: duration)
    }
}

public extension MarkdownStreamingTransition where Self == IdentityStreamingTransition {
    static var identity: Self { Self() }
}

extension MarkdownStreamingTransition {
    var viewTransition: (any ViewTransition)? {
        self is IdentityStreamingTransition ? nil : StreamingViewTransition(transition: self)
    }
}

struct StreamingViewTransition: ViewTransition {
    let transition: any MarkdownStreamingTransition

    func animate(_ view: UIView, completion: @escaping () -> Void) {
        transition.animate(view, completion: completion)
    }
}
