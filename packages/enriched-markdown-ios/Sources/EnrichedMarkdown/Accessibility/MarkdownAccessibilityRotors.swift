import UIKit

/// VoiceOver rotors that jump between headings, links, and images of one
/// rendered document. A rotor is only offered when it has somewhere to go.
enum MarkdownAccessibilityRotors {
    static func rotors(
        for elements: [UIAccessibilityElement],
        labels: MarkdownAccessibilityLabels
    ) -> [UIAccessibilityCustomRotor] {
        let groups: [(name: String, trait: UIAccessibilityTraits)] = [
            (labels.rotor.headings, .header),
            (labels.rotor.links, .link),
            (labels.rotor.images, .image)
        ]
        return groups.compactMap { group in
            let members = elements.filter { $0.accessibilityTraits.contains(group.trait) }
            guard !members.isEmpty else { return nil }
            return rotor(named: group.name, over: members)
        }
    }

    private static func rotor(named name: String, over elements: [UIAccessibilityElement]) -> UIAccessibilityCustomRotor {
        UIAccessibilityCustomRotor(name: name) { predicate in
            let current = (predicate.currentItem.targetElement as? UIAccessibilityElement)
                .flatMap { element in elements.firstIndex { $0 === element } }
            let next: Int
            switch predicate.searchDirection {
            case .next:
                next = current.map { $0 + 1 } ?? 0
            case .previous:
                next = current.map { $0 - 1 } ?? elements.count - 1
            @unknown default:
                return nil
            }
            guard elements.indices.contains(next) else { return nil }
            return UIAccessibilityCustomRotorItemResult(targetElement: elements[next], targetRange: nil)
        }
    }
}
