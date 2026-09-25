import EnrichedMarkdown
import EnrichedMarkdownLaTeX
import SwiftUI

/// The three ways a block image can be sized, cycled by the playground button.
private enum ImageSizingOption: CaseIterable {
    case height
    case maxHeight
    case aspectRatio

    /// The button title paired with the modifier it stands for, so the two
    /// cannot drift apart.
    var labelled: (label: String, image: BlockImage) {
        switch self {
        case .height: return ("Height 200", BlockImage().height(200))
        case .maxHeight: return ("Max 150", BlockImage().maxHeight(150))
        case .aspectRatio: return ("16:9", BlockImage().aspectRatio(16 / 9))
        }
    }
}

/// The sizing's own default first, then every explicit mode.
private let imageContentModeCycle: [ImageContentMode?] = [nil] + ImageContentMode.allCases

private func cycled<T: Equatable>(_ current: T, in options: [T]) -> T {
    let index = options.firstIndex(of: current) ?? 0
    return options[(index + 1) % options.count]
}

struct PlaygroundScreen: View {
    // MARK: - Properties

    @State private var markdown: String = ""
    @State private var underlineEnabled: Bool = true
    @State private var selectableEnabled: Bool = true
    @State private var setMarkdownSheetVisible: Bool = false
    @State private var rawInput: String = ""
    @State private var blockImageURI: String?
    @State private var inlineImageURI: String?
    @State private var longPressedLink: String = ""
    @State private var linkAlertVisible: Bool = false
    @State private var acceptImageType: String = "image/png"
    @State private var spoilerOverlay: PlaygroundSpoilerOverlay = .particles
    @State private var imageSizing: ImageSizingOption = .height
    @State private var imageContentMode: ImageContentMode?

    // MARK: - Views

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    PlaygroundButton(label: "Blur", accessibilityId: "blur-button") {}
                    PlaygroundButton(
                        label: "Underline",
                        accessibilityId: "underline-button",
                        isActive: underlineEnabled
                    ) {
                        underlineEnabled.toggle()
                    }
                    PlaygroundButton(
                        label: "Selectable",
                        accessibilityId: "selectable-button",
                        isActive: selectableEnabled
                    ) {
                        selectableEnabled.toggle()
                    }
                }

                HStack(spacing: 8) {
                    PlaygroundButton(label: "Insert Image", accessibilityId: "insert-image-button") {
                        insertBlockImage()
                    }
                    PlaygroundButton(label: "Insert Inline Image", accessibilityId: "insert-inline-image-button") {
                        insertInlineImage()
                    }
                }

                HStack(spacing: 8) {
                    PlaygroundButton(label: "Insert Header Image", accessibilityId: "insert-header-image-button") {
                        insertHeaderImage()
                    }
                    PlaygroundButton(
                        label: "Accept: \(acceptImageType == "image/png" ? "PNG" : "JPEG")",
                        accessibilityId: "accept-header-button",
                        isActive: acceptImageType == "image/png"
                    ) {
                        acceptImageType = acceptImageType == "image/png" ? "image/jpeg" : "image/png"
                    }
                    PlaygroundButton(label: "Insert Data URI Image", accessibilityId: "insert-data-uri-image-button") {
                        insertDataURIImage()
                    }
                }

                HStack(spacing: 8) {
                    PlaygroundButton(
                        label: "Sizing: \(imageSizing.labelled.label)",
                        accessibilityId: "image-sizing-button"
                    ) {
                        imageSizing = cycled(imageSizing, in: ImageSizingOption.allCases)
                    }
                    PlaygroundButton(
                        label: "Mode: \(imageContentModeLabel)",
                        accessibilityId: "image-content-mode-button"
                    ) {
                        imageContentMode = cycled(imageContentMode, in: imageContentModeCycle)
                    }
                    PlaygroundButton(label: "Insert Photo", accessibilityId: "insert-photo-button") {
                        insertPhoto()
                    }
                }

                HStack(spacing: 8) {
                    PlaygroundButton(label: "Insert Math", accessibilityId: "insert-math-button") {
                        insertMath()
                    }
                    PlaygroundButton(
                        label: "Spoiler: \(spoilerOverlay.rawValue)",
                        accessibilityId: "spoiler-overlay-button"
                    ) {
                        spoilerOverlay = spoilerOverlay.next
                    }
                }

                setMarkdownButton
                preview
            }
            .padding(16)
        }
        .background(Color.gray50)
        .accessibilityIdentifier("playground-screen")
        .markdownTheme(PlaygroundMarkdownTheme)
        .markdownSelectionMenu(MarkdownSelectionMenuConfig())
        .markdownSelectable(selectableEnabled)
        .markdownSpoilerOverlay(spoilerOverlay.provider)
        .markdownSelectionColor(.orange)
        .markdownImageRequestHeaders(["Accept": acceptImageType])
        .markdownLaTeX()
        .onLinkLongPress { url in
            longPressedLink = url.absoluteString
            linkAlertVisible = true
        }
        .alert("Link long-pressed", isPresented: $linkAlertVisible) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(longPressedLink)
        }
        .onAppear(perform: loadBundledImages)
        .sheet(isPresented: $setMarkdownSheetVisible) {
            SetMarkdownSheet(
                rawInput: $rawInput,
                onCancel: { setMarkdownSheetVisible = false },
                onConfirm: {
                    markdown = rawInput
                    setMarkdownSheetVisible = false
                }
            )
        }
    }

    private var setMarkdownButton: some View {
        Button("Set Raw Markdown") {
            rawInput = ""
            setMarkdownSheetVisible = true
        }
        .buttonStyle(.pillPrimary)
        .accessibilityIdentifier("set-markdown-button")
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.gray400)

            Group {
                if markdown.isEmpty {
                    Text("Preview will appear here")
                        .font(.body.italic())
                        .foregroundStyle(Color.gray400)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .accessibilityIdentifier("preview-empty")
                } else {
                    EnrichedMarkdownText(
                        markdown,
                        flags: Md4cFlags(
                            underline: underlineEnabled,
                            superscript: true,
                            subscript: true,
                            highlight: true,
                            admonitions: true
                        )
                    )
                        .markdownTheme(imageSizingTheme)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .accessibilityIdentifier("preview-text")
                }
            }
            .background(Color.white, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray300, lineWidth: 1)
            )
            .accessibilityIdentifier("preview-container")
        }
    }

    // MARK: - Methods

    private func loadBundledImages() {
        blockImageURI = Bundle.main.imageURI(named: "logo", extension: "png")
        inlineImageURI = Bundle.main.imageURI(named: "logo_icon", extension: "png")
    }

    private var imageContentModeLabel: String {
        imageContentMode?.rawValue.capitalized ?? "Default"
    }

    /// Layered over the screen theme so the sizing buttons restyle block
    /// images live.
    private var imageSizingTheme: MarkdownTheme {
        var image = imageSizing.labelled.image
        if let imageContentMode {
            image = image.contentMode(imageContentMode)
        }
        return MarkdownTheme { image }
    }

    /// A tall remote photo, so fill, fit and original differ visibly from
    /// each other and from the wide bundled logo.
    private func insertPhoto() {
        let url = "https://images.unsplash.com/photo-1448375240586-882707db888b?w=800"
        appendBlock("![Misty forest at sunrise](\(url))")
    }

    private func insertBlockImage() {
        guard let uri = blockImageURI else { return }
        let imageMarkdown = "![logo](\(uri))"
        appendBlock(imageMarkdown)
    }

    private func insertInlineImage() {
        guard let uri = inlineImageURI else { return }
        markdown = "Enriched Markdown is a library for ![icon](\(uri)) React Native."
    }

    private func insertDataURIImage() {
        guard
            let url = Bundle.main.url(forResource: "logo_icon", withExtension: "png"),
            let data = try? Data(contentsOf: url)
        else { return }
        let imageMarkdown = "Rendered from a data URI: ![data uri icon](data:image/png;base64,\(data.base64EncodedString()))"
        appendBlock(imageMarkdown)
    }

    private func insertMath() {
        let mathMarkdown = """
        Inline math like $E = mc^2$ flows with the text, and display math stands alone:

        $$
        \\int_{-\\infty}^{\\infty} e^{-x^2}\\,dx = \\sqrt{\\pi}
        $$
        """
        appendBlock(mathMarkdown)
    }

    private func appendBlock(_ block: String) {
        markdown = markdown.isEmpty ? block : markdown + "\n\n" + block
    }

    // httpbingo.org negotiates the response image from the Accept header (and
    // rejects requests without one), so this image only renders because
    // markdownImageRequestHeaders reaches the wire — and toggling the header
    // shows a different image for the same URL via the header-aware cache.
    private func insertHeaderImage() {
        let imageMarkdown = "![header image](https://httpbingo.org/image)"
        appendBlock(imageMarkdown)
    }
}

// MARK: -

#Preview {
    PlaygroundScreen()
}
