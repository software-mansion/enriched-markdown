import UIKit
import UniformTypeIdentifiers

struct CodeBlockAttachmentStyle: Equatable {
    var font: UIFont = .monospacedSystemFont(ofSize: 14, weight: .regular)
    var textColor: UIColor = .label
    var backgroundColor: UIColor
    var borderColor: UIColor
    var borderWidth: CGFloat
    var cornerRadius: CGFloat
    var padding: CGFloat
    var lineHeight: CGFloat = 0
    var marginTop: CGFloat = 0
    var marginBottom: CGFloat = 0
    var headerForegroundColor: UIColor?

    static let headerLabelScale: CGFloat = 0.85
    static let headerIconScale: CGFloat = 0.72
    static let headerSecondaryAlpha: CGFloat = 0.6
    static let headerDividerAlpha: CGFloat = 0.2

    init(config: MarkdownStyleConfiguration) {
        let decoration = BlockDecorationConfig(styleConfig: config)
        backgroundColor = decoration.codeBlockBackgroundColor
        borderColor = decoration.codeBlockBorderColor
        borderWidth = decoration.codeBlockBorderWidth
        cornerRadius = decoration.codeBlockBorderRadius
        padding = decoration.codeBlockPadding

        let style = config.codeBlock
        if let value = style.font { font = value }
        if let value = style.foregroundColor { textColor = value }
        if let value = style.lineHeight { lineHeight = value }
        if let value = style.marginTop { marginTop = value }
        if let value = style.marginBottom { marginBottom = value }
        headerForegroundColor = style.headerForegroundColor
    }

    var headerFont: UIFont {
        .systemFont(ofSize: font.pointSize * Self.headerLabelScale, weight: .medium)
    }

    var headerTextColor: UIColor {
        headerForegroundColor ?? textColor.withAlphaComponent(Self.headerSecondaryAlpha)
    }

    var dividerColor: UIColor {
        headerForegroundColor?.withAlphaComponent(Self.headerDividerAlpha / Self.headerSecondaryAlpha)
            ?? textColor.withAlphaComponent(Self.headerDividerAlpha)
    }
}

struct CodeBlockAttachmentLayout: Equatable {
    let codeSize: CGSize
    let contentInset: CGFloat
    let headerHeight: CGFloat

    var dividerY: CGFloat { headerHeight + contentInset / 2 }
    var headerCenterY: CGFloat { (headerHeight + contentInset / 2) / 2 }
    var totalHeight: CGFloat { headerHeight + contentInset * 2 + codeSize.height }

    /// Measured: a themed line height's baseline offset shortens TextKit 2 fragments.
    static func compute(attributedCode: NSAttributedString, style: CodeBlockAttachmentStyle) -> CodeBlockAttachmentLayout {
        let bounding = attributedCode.boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        let height = attributedCode.length == 0 ? 0 : ceil(bounding.height)
        let contentInset = style.padding + style.borderWidth
        return CodeBlockAttachmentLayout(
            codeSize: CGSize(width: ceil(bounding.width), height: height),
            contentInset: contentInset,
            headerHeight: contentInset + ceil(style.headerFont.lineHeight)
        )
    }
}

final class CodeBlockAttachment: NSTextAttachment, MarkdownPluginAttachment, HostedBlockAttachment {
    /// Must be a resolvable UTI — NSTextAttachment silently drops any other
    /// string, which breaks the provider-class lookup.
    static let fileType: String = UTType(
        filenameExtension: "enriched-markdown-code"
    )?.identifier ?? "public.data"

    /// UIKit installs the view only via this registration; overriding
    /// `viewProvider(for:...)` on the attachment breaks it.
    private static let providerRegistration: Void = {
        NSTextAttachment.registerViewProviderClass(
            CodeBlockAttachmentViewProvider.self,
            forFileType: CodeBlockAttachment.fileType
        )
    }()

    let code: String
    let language: String?
    let fenceCharacter: String
    let attributedCode: NSAttributedString
    let style: CodeBlockAttachmentStyle
    let layout: CodeBlockAttachmentLayout
    let isPending: Bool

    /// Kept across provider recreations; a fresh view blanks the context-menu lift.
    var hostedView: CodeBlockAttachmentView?

    func makeHostedView() -> CodeBlockAttachmentView {
        CodeBlockAttachmentView(attachment: self)
    }

    @MainActor
    func update(_ view: CodeBlockAttachmentView, transition: (any ViewTransition)?) {
        view.update(to: self, transition: transition)
    }

    init(
        code: String,
        language: String?,
        fenceCharacter: String,
        attributedCode: NSAttributedString,
        style: CodeBlockAttachmentStyle,
        isPending: Bool = false
    ) {
        self.code = code
        self.language = language
        self.fenceCharacter = fenceCharacter
        self.attributedCode = attributedCode
        self.style = style
        self.isPending = isPending
        self.layout = CodeBlockAttachmentLayout.compute(attributedCode: attributedCode, style: style)
        _ = Self.providerRegistration
        // fileType only persists with non-nil contents; the data is never read.
        super.init(data: Data("code".utf8), ofType: Self.fileType)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var displayLanguage: String? {
        language.map(CodeBlockLanguageNames.displayName)
    }

    var isBlock: Bool { true }

    var literalText: String { code }

    func markdownText() -> String {
        var fenceLength = 3
        var run = 0
        for character in code {
            run = String(character) == fenceCharacter ? run + 1 : 0
            fenceLength = max(fenceLength, run + 1)
        }
        let fence = String(repeating: fenceCharacter, count: fenceLength)
        let opening = fence + (language ?? "")
        return code.isEmpty ? "\(opening)\n\(fence)" : "\(opening)\n\(code)\n\(fence)"
    }

    static func attributedCode(_ code: String, style: CodeBlockAttachmentStyle) -> NSMutableAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.baseWritingDirection = .leftToRight
        paragraphStyle.lineBreakMode = .byClipping

        let output = NSMutableAttributedString(string: code, attributes: [
            .font: style.font,
            .foregroundColor: style.textColor,
            .paragraphStyle: paragraphStyle
        ])
        if style.lineHeight > 0 {
            ParagraphStyleHelpers.applyBlockLineHeight(
                to: output,
                range: NSRange(location: 0, length: output.length),
                lineHeight: style.lineHeight
            )
        }
        return output
    }
}
