import Foundation

/// Strings VoiceOver speaks while navigating rendered markdown. Every
/// field defaults to English; override the ones your app localizes.
///
/// Templates use `{n}` for a 1-based index (list item number, table row),
/// `{content}` for a table row's comma-joined cell text. Translations must
/// keep the placeholder names. Defaults use the cardinal form ("List item
/// 2") so a single template works without per-language plural rules.
public struct MarkdownAccessibilityLabels: Equatable, Sendable {
    /// Spoken after a list item's text (VoiceOver value) at one nesting
    /// level.
    public struct ListLevel: Equatable, Sendable {
        public var bulletPoint: String
        /// `{n}` → 1-based item number.
        public var orderedItem: String
        public var checkedTask: String
        public var uncheckedTask: String

        public init(bulletPoint: String, orderedItem: String, checkedTask: String, uncheckedTask: String) {
            self.bulletPoint = bulletPoint
            self.orderedItem = orderedItem
            self.checkedTask = checkedTask
            self.uncheckedTask = uncheckedTask
        }
    }

    /// One set of list labels for top-level items and one for items inside
    /// another list.
    public struct List: Equatable, Sendable {
        public var top: ListLevel
        public var nested: ListLevel

        public init(
            top: ListLevel = ListLevel(
                bulletPoint: "Bullet point",
                orderedItem: "List item {n}",
                checkedTask: "Task, checked",
                uncheckedTask: "Task, not checked"
            ),
            nested: ListLevel = ListLevel(
                bulletPoint: "Nested bullet point",
                orderedItem: "Nested list item {n}",
                checkedTask: "Nested task, checked",
                uncheckedTask: "Nested task, not checked"
            )
        ) {
            self.top = top
            self.nested = nested
        }
    }

    /// Spoken after content inside a blockquote.
    public struct Blockquote: Equatable, Sendable {
        public var quote: String
        public var nestedQuote: String

        public init(quote: String = "Blockquote", nestedQuote: String = "Nested blockquote") {
            self.quote = quote
            self.nestedQuote = nestedQuote
        }
    }

    public struct Table: Equatable, Sendable {
        /// `{n}` → 1-based row index, `{content}` → comma-joined cell text.
        public var row: String

        public init(row: String = "Row {n}: {content}") {
            self.row = row
        }
    }

    public struct Image: Equatable, Sendable {
        /// Spoken for an image whose markdown has no alt text.
        public var fallback: String

        public init(fallback: String = "Image") {
            self.fallback = fallback
        }
    }

    public struct CodeBlock: Equatable, Sendable {
        /// Name of the VoiceOver custom action that copies the block.
        public var copy: String

        public init(copy: String = "Copy code") {
            self.copy = copy
        }
    }

    /// Names of the VoiceOver rotors (the jump-by-type navigator).
    public struct Rotor: Equatable, Sendable {
        public var headings: String
        public var links: String
        public var images: String

        public init(headings: String = "Headings", links: String = "Links", images: String = "Images") {
            self.headings = headings
            self.links = links
            self.images = images
        }
    }

    public var list: List
    public var blockquote: Blockquote
    public var table: Table
    public var image: Image
    public var codeBlock: CodeBlock
    public var rotor: Rotor

    public init(
        list: List = List(),
        blockquote: Blockquote = Blockquote(),
        table: Table = Table(),
        image: Image = Image(),
        codeBlock: CodeBlock = CodeBlock(),
        rotor: Rotor = Rotor()
    ) {
        self.list = list
        self.blockquote = blockquote
        self.table = table
        self.image = image
        self.codeBlock = codeBlock
        self.rotor = rotor
    }

    public static let `default` = MarkdownAccessibilityLabels()
}
