/// The GitHub alert types; the parser's `admonitionType` attribute is always
/// one of these raw values.
public enum AdmonitionType: String, CaseIterable, Sendable {
    case note
    case tip
    case important
    case warning
    case caution

    /// The header label ("Note").
    var title: String { rawValue.capitalized }
}
