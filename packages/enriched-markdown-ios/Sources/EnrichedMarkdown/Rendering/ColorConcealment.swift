import UIKit

enum ColorConcealment {
    private static let keys: [NSAttributedString.Key] = [.foregroundColor, .underlineColor, .strikethroughColor]

    static func conceal(_ output: NSMutableAttributedString, in range: NSRange, stash key: NSAttributedString.Key) {
        output.enumerateAttributes(in: range, options: []) { attrs, runRange, _ in
            var stash = attrs[key] as? [NSAttributedString.Key: UIColor] ?? [:]
            var changes: [NSAttributedString.Key: Any] = [:]
            for colorKey in keys {
                guard let color = attrs[colorKey] as? UIColor, color != .clear else { continue }
                stash[colorKey] = color
                changes[colorKey] = UIColor.clear
            }
            guard !changes.isEmpty else { return }
            changes[key] = stash
            output.addAttributes(changes, range: runRange)
        }
    }

    static func reveal(_ output: NSMutableAttributedString, in range: NSRange, stash key: NSAttributedString.Key) {
        output.enumerateAttribute(key, in: range) { stash, runRange, _ in
            guard let stash = stash as? [NSAttributedString.Key: UIColor] else { return }
            output.addAttributes(stash, range: runRange)
            output.removeAttribute(key, range: runRange)
        }
    }
}
