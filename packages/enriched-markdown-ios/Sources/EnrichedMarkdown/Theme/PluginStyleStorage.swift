import Foundation

/// A style record an optional module keeps in `MarkdownStyleConfig.pluginStyles`,
/// written by its theme elements and read by its renderers.
package protocol PluginStyle: Equatable, Sendable {
    /// Overlays `other`'s set properties, the way the built-in styles merge.
    mutating func merge(_ other: Self)
}

/// `PluginStyle` records keyed by their type, one per module concern.
package struct PluginStyleStorage: Equatable, Sendable {
    private var values: [ObjectIdentifier: any PluginStyle] = [:]

    package init() {}

    package subscript<Style: PluginStyle>(_ type: Style.Type) -> Style? {
        get { values[ObjectIdentifier(type)] as? Style }
        set { values[ObjectIdentifier(type)] = newValue }
    }

    package mutating func merge(_ other: PluginStyleStorage) {
        for (key, style) in other.values {
            values[key] = values[key].map { $0.merged(with: style) } ?? style
        }
    }

    package static func == (lhs: PluginStyleStorage, rhs: PluginStyleStorage) -> Bool {
        guard lhs.values.count == rhs.values.count else { return false }
        return lhs.values.allSatisfy { key, style in
            rhs.values[key].map { style.isEqual(to: $0) } ?? false
        }
    }
}

private extension PluginStyle {
    func isEqual(to other: any PluginStyle) -> Bool {
        guard let other = other as? Self else { return false }
        return self == other
    }

    /// A key holds one type, so the mismatch fallback is unreachable.
    func merged(with other: any PluginStyle) -> any PluginStyle {
        guard let other = other as? Self else { return other }
        var copy = self
        copy.merge(other)
        return copy
    }
}
