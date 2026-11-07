import UIKit

package protocol HostedBlockAttachment: NSTextAttachment {
    associatedtype HostedView: HostedBlockView

    var hostedView: HostedView? { get set }

    func makeHostedView() -> HostedView

    @MainActor
    func update(_ view: HostedView, transition: (any ViewTransition)?)
}

package extension HostedBlockAttachment {
    func loadHostedView() -> any HostedBlockView {
        let view = hostedView ?? makeHostedView()
        hostedView = view
        return view
    }

    @MainActor
    func adoptView(from predecessor: NSTextAttachment, transition: (any ViewTransition)?) {
        guard let predecessor = predecessor as? Self, let view = predecessor.hostedView else { return }
        predecessor.hostedView = nil
        hostedView = view
        update(view, transition: transition)
    }
}

package protocol HostedBlockView: UIView {
    var owner: ObjectIdentifier? { get set }
}

protocol StreamingBlockView: HostedBlockView {
    func animateContentIn(with transition: any ViewTransition)
}

package class HostedBlockViewProvider: NSTextAttachmentViewProvider {
    private var hosted: (any HostedBlockView)?

    override package init(
        textAttachment: NSTextAttachment,
        parentView: UIView?,
        textLayoutManager: NSTextLayoutManager?,
        location: NSTextLocation
    ) {
        super.init(
            textAttachment: textAttachment,
            parentView: parentView,
            textLayoutManager: textLayoutManager,
            location: location
        )
        tracksTextAttachmentViewBounds = true
    }

    override package func loadView() {
        guard let attachment = textAttachment as? any HostedBlockAttachment else {
            view = UIView()
            return
        }
        let hosted = attachment.loadHostedView()
        hosted.owner = ObjectIdentifier(self)
        self.hosted = hosted
        view = hosted
    }

    deinit {
        if let hosted, hosted.owner != ObjectIdentifier(self) {
            view = nil
        }
    }
}
