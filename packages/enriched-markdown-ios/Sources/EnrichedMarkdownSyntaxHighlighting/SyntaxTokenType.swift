public enum SyntaxTokenType: UInt8, CaseIterable, Sendable {
    case keyword
    case `operator`
    case punctuation
    case string
    case number
    case constant
    case comment
    case function
    case type
    case variable
    case property
    case tag
    case attribute
    case embedded
}
