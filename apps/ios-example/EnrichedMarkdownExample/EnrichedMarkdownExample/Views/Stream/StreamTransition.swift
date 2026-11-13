import EnrichedMarkdown
import EnrichedMarkdownStreaming
import UIKit

enum StreamTransition: String, CaseIterable, Identifiable {
    case opacity = "Fade"
    case identity = "None"
    case rise = "Rise"

    var id: Self { self }

    var transition: any MarkdownStreamingTransition {
        switch self {
        case .opacity: return .opacity
        case .identity: return .identity
        case .rise: return RiseTransition()
        }
    }
}

struct RiseTransition: MarkdownStreamingTransition {
    func animate(_ view: UIView, completion: @escaping () -> Void) {
        view.alpha = 0
        view.transform = CGAffineTransform(translationX: 0, y: 6)
        UIView.animate(withDuration: 0.35, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
            view.alpha = 1
            view.transform = .identity
        } completion: { _ in
            completion()
        }
    }
}
