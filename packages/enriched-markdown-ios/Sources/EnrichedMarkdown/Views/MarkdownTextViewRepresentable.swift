import SwiftUI
import UIKit

struct MarkdownTextViewRepresentable: UIViewRepresentable {
    let attributedText: NSAttributedString
    let source: RenderedSource?
    let styleConfig: MarkdownStyleConfig
    let onLinkPress: ((URL) -> Void)?
    let onLinkLongPress: ((URL) -> Void)?
    let selectionMenuConfig: MarkdownSelectionMenuConfig
    let isSelectionEnabled: Bool
    let selectionColor: Color?
    let onTaskListItemTap: ((TaskListInteraction.Hit) -> Void)?
    let spoilerOverlay: MarkdownSpoilerOverlay
    let onSpoilerTap: ((NSRange) -> Void)?
    let accessibilityLabels: MarkdownAccessibilityLabels

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MarkdownTextView {
        let textView = MarkdownTextView()
        textView.delegate = context.coordinator
        textView.styleConfig = styleConfig
        return textView
    }

    func updateUIView(_ textView: MarkdownTextView, context: Context) {
        context.coordinator.onLinkPress = onLinkPress
        context.coordinator.onLinkLongPress = onLinkLongPress
        context.coordinator.source = source
        context.coordinator.selectionMenuConfig = selectionMenuConfig
        textView.onLinkPress = onLinkPress
        textView.styleConfig = styleConfig
        textView.isSelectionEnabled = isSelectionEnabled
        textView.tintColor = selectionColor.map { UIColor($0) }
        textView.onTaskListItemTap = onTaskListItemTap
        textView.spoilerOverlays.mode = spoilerOverlay
        textView.onSpoilerTap = onSpoilerTap
        textView.accessibilityLabels = accessibilityLabels
        textView.setMarkdownAttributedText(attributedText)
    }

    static func dismantleUIView(_ uiView: MarkdownTextView, coordinator: Coordinator) {
        uiView.delegate = nil
        uiView.onTaskListItemTap = nil
        uiView.onSpoilerTap = nil
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: MarkdownTextView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: size.height)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var onLinkPress: ((URL) -> Void)?
        var onLinkLongPress: ((URL) -> Void)?
        var source: RenderedSource?
        var selectionMenuConfig = MarkdownSelectionMenuConfig()

        /// Routes a link tap; returns true when a handler consumed it.
        func handleLinkPress(_ url: URL) -> Bool {
            guard let onLinkPress else { return false }
            onLinkPress(url)
            return true
        }

        /// Routes a link long-press; returns true when a handler consumed it.
        /// Without a long-press handler, a press handler consumes every link
        /// interaction (pre-existing behavior: suppresses the system
        /// menu/preview and fires the press).
        func handleLinkLongPress(_ url: URL) -> Bool {
            if let onLinkLongPress {
                onLinkLongPress(url)
                return true
            }
            return handleLinkPress(url)
        }

        /// See `MarkdownTextView.isTouchOnSelectionHandle`: a selection knob
        /// parked over a link would otherwise fire it on drag start.
        private func isGrabbingSelectionHandle(_ textView: UITextView) -> Bool {
            (textView as? SelectionHandleTouchReporting)?.isTouchOnSelectionHandle ?? false
        }

        // iOS 16 (and 17+ fallback when the UITextItem methods are
        // unavailable): tap arrives as .invokeDefaultAction, long-press as
        // .presentActions or .preview.
        func textView(
            _ textView: UITextView,
            shouldInteractWith URL: URL,
            in characterRange: NSRange,
            interaction: UITextItemInteraction
        ) -> Bool {
            // `false` suppresses the system preview, as `nil` does for the two
            // UITextItem callbacks below.
            guard !isGrabbingSelectionHandle(textView) else { return false }

            switch interaction {
            case .invokeDefaultAction:
                return !handleLinkPress(URL)
            case .presentActions, .preview:
                return !handleLinkLongPress(URL)
            @unknown default:
                return true
            }
        }

        @available(iOS 17.0, *)
        func textView(
            _ textView: UITextView,
            primaryActionFor textItem: UITextItem,
            defaultAction: UIAction
        ) -> UIAction? {
            guard !isGrabbingSelectionHandle(textView) else { return nil }
            guard case .link(let url) = textItem.content, let onLinkPress else {
                return defaultAction
            }
            return UIAction { _ in onLinkPress(url) }
        }

        @available(iOS 17.0, *)
        func textView(
            _ textView: UITextView,
            menuConfigurationFor textItem: UITextItem,
            defaultMenu: UIMenu
        ) -> UITextItem.MenuConfiguration? {
            guard !isGrabbingSelectionHandle(textView) else { return nil }
            guard case .link(let url) = textItem.content else {
                return UITextItem.MenuConfiguration(menu: defaultMenu)
            }
            return handleLinkLongPress(url) ? nil : UITextItem.MenuConfiguration(menu: defaultMenu)
        }

        func textView(
            _ textView: UITextView,
            editMenuForTextIn range: NSRange,
            suggestedActions: [UIMenuElement]
        ) -> UIMenu? {
            let specs = SelectionMenuItems.build(
                config: selectionMenuConfig,
                selectedRange: range,
                attributedText: textView.attributedText ?? NSAttributedString(),
                source: source
            )
            var actions = specs.map(Self.makeAction(for:))

            // Recent iOS versions stop suggesting Select All for non-editable text
            // views, leaving no way to grow a long-press selection to the whole
            // document; provide it ourselves when the system didn't.
            // The system shows its own item only when the command is suggested AND
            // canPerformAction allows it; recent iOS returns false there for
            // non-editable text views, hiding Select All even though the command
            // is present in suggestedActions.
            let textLength = textView.attributedText?.length ?? 0
            let systemShowsSelectAll = Self.containsSelectAll(suggestedActions)
                && textView.canPerformAction(#selector(UIResponder.selectAll(_:)), withSender: nil)
            if range.length < textLength, !systemShowsSelectAll {
                actions.append(Self.makeSelectAllAction(for: textView))
            }

            guard !actions.isEmpty else { return UIMenu(children: suggestedActions) }
            return UIMenu(children: Self.splice(actions, into: suggestedActions))
        }

        static func makeAction(for spec: MenuItemSpec) -> UIAction {
            UIAction(
                title: spec.title,
                image: UIImage(systemName: spec.systemImageName),
                identifier: UIAction.Identifier(spec.identifier)
            ) { _ in
                UIPasteboard.general.string = spec.pasteboardString
            }
        }

        static func makeSelectAllAction(for textView: UITextView) -> UIAction {
            UIAction(
                title: "Select All",
                image: UIImage(systemName: "text.badge.checkmark"),
                identifier: UIAction.Identifier("com.swmansion.enriched.markdown.selectAll")
            ) { [weak textView] _ in
                guard let textView else { return }
                Self.selectEntireDocument(in: textView)
            }
        }

        static func selectEntireDocument(in textView: UITextView) {
            textView.selectedRange = NSRange(location: 0, length: textView.attributedText?.length ?? 0)
        }

        static func containsSelectAll(_ elements: [UIMenuElement]) -> Bool {
            elements.contains { element in
                if let command = element as? UICommand, command.action == #selector(UIResponder.selectAll(_:)) {
                    return true
                }
                if let menu = element as? UIMenu {
                    return containsSelectAll(menu.children)
                }
                return false
            }
        }

        /// Inserts `actions` right after the system standard-edit submenu,
        /// keeping every system item (dropping them would remove Select All,
        /// which is the only way to grow a selection from the long-press menu
        /// of a non-editable text view). Falls back to prepending when the
        /// submenu is absent.
        static func splice(_ actions: [UIMenuElement], into suggestedActions: [UIMenuElement]) -> [UIMenuElement] {
            var result: [UIMenuElement] = []
            var foundStandardEdit = false

            for element in suggestedActions {
                result.append(element)
                if !foundStandardEdit, let menu = element as? UIMenu, menu.identifier == .standardEdit {
                    result.append(contentsOf: actions)
                    foundStandardEdit = true
                }
            }

            if !foundStandardEdit {
                result.insert(contentsOf: actions, at: 0)
            }
            return result
        }
    }
}
