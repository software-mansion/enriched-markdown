import Foundation

enum MarkdownAttributeValue {
    static func intValue(from value: Any?) -> Int? {
        if let int = value as? Int {
            return int
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        return nil
    }

    /// A `.link` value (`URL` or `String`) as a string.
    static func linkString(from value: Any?) -> String? {
        switch value {
        case let url as URL: return url.absoluteString
        case let string as String: return string
        default: return nil
        }
    }

    /// The run's link, including one hidden by a concealed spoiler.
    static func sourceLink(in attrs: [NSAttributedString.Key: Any]) -> Any? {
        attrs[.link] ?? attrs[MarkdownAttribute.spoilerLink]
    }

    static func boolValue(from value: Any?) -> Bool {
        if let bool = value as? Bool {
            return bool
        }
        if let number = value as? NSNumber {
            return number.boolValue
        }
        return false
    }
}
