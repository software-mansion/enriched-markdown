import EnrichedMarkdown
import EnrichedMarkdownLaTeX
import SwiftUI

/// Long-form article rendered entirely from markdown — prose, LaTeX math, a
/// figure, a table and a code block — to show the library carrying a real
/// document rather than a feature checklist.
///
/// The masthead and the colophon are SwiftUI; everything between them is a
/// single `EnrichedMarkdownText`, on the same warm paper and the same 30pt
/// baseline, so the seam between app chrome and rendered markdown disappears.
struct ArticleScreen: View {
    // MARK: - Properties

    let article: Article

    @Environment(\.colorScheme) private var systemColorScheme
    @State private var schemeOverride: ColorScheme?
    @State private var pressedLink: URL?
    @State private var linkAlertVisible: Bool = false
    @State private var scrollOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var hasAppeared: Bool = false

    private static let scrollSpace = "article-scroll"
    /// Text column margin, and the width block figures are measured against.
    private static let gutter: CGFloat = 24
    /// Aspect ratio both bundled figures were drawn at.
    private static let figureRatio: CGFloat = 0.52

    private var effectiveScheme: ColorScheme {
        schemeOverride ?? systemColorScheme
    }

    private var palette: ArticlePalette {
        ArticlePalette.forScheme(effectiveScheme)
    }

    // MARK: - Views

    var body: some View {
        GeometryReader { viewport in
            let columnWidth = viewport.size.width - Self.gutter * 2

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    offsetSentinel

                    ArticleMasthead(
                        article: article,
                        palette: palette,
                        gutter: Self.gutter,
                        viewport: viewport.size
                    )
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 12)

                    ArticleBody(
                        markdown: article.body,
                        palette: palette,
                        figureHeight: (columnWidth * Self.figureRatio).rounded(),
                        gutter: Self.gutter,
                        onLinkPress: { url in
                            pressedLink = url
                            linkAlertVisible = true
                        }
                    )
                    .equatable()

                    ArticleColophon(palette: palette, gutter: Self.gutter)
                        .padding(.bottom, 72)
                }
                .background(contentHeightReader)
            }
            .scrollIndicators(.hidden)
            .coordinateSpace(name: Self.scrollSpace)
            .safeAreaInset(edge: .top, spacing: 0) {
                ArticleReadingProgress(
                    progress: readingProgress(viewportHeight: viewport.size.height),
                    palette: palette
                )
            }
            .overlay(alignment: .bottomTrailing) {
                appearanceToggle
            }
        }
        .background(palette.paper.ignoresSafeArea())
        .markdownSelectionColor(palette.accent.opacity(0.28))
        .preferredColorScheme(schemeOverride)
        .tint(palette.accent)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(palette.paper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(effectiveScheme, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(article.title)
                    .font(.articleSerif(16))
                    .foregroundStyle(palette.heading)
                    .opacity(runningTitleOpacity)
                    .accessibilityHidden(runningTitleOpacity < 0.5)
            }
        }
        .onPreferenceChange(ArticleScrollOffsetKey.self) { scrollOffset = $0 }
        .onPreferenceChange(ArticleContentHeightKey.self) { contentHeight = $0 }
        .onAppear {
            withAnimation(.easeOut(duration: 0.45).delay(0.05)) { hasAppeared = true }
        }
        .alert("Link Pressed!", isPresented: $linkAlertVisible, presenting: pressedLink) { url in
            Button("Open in Browser") {
                UIApplication.shared.open(url)
            }
            Button("Cancel", role: .cancel) {}
        } message: { url in
            Text("You tapped on: \(url.absoluteString)")
        }
    }

    /// Zero-height probe: its distance from the top of the scroll view is how
    /// far the article has been read.
    private var offsetSentinel: some View {
        GeometryReader { frame in
            Color.clear.preference(
                key: ArticleScrollOffsetKey.self,
                value: frame.frame(in: .named(Self.scrollSpace)).minY
            )
        }
        .frame(height: 0)
    }

    private var contentHeightReader: some View {
        GeometryReader { frame in
            Color.clear.preference(key: ArticleContentHeightKey.self, value: frame.size.height)
        }
    }

    /// Inverted-ink disc, kept clear of the text column so a tap during a demo
    /// never lands on a link.
    private var appearanceToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                schemeOverride = effectiveScheme == .dark ? .light : .dark
            }
        } label: {
            Image(systemName: effectiveScheme == .dark ? "sun.max.fill" : "moon.fill")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(palette.paper)
                .rotationEffect(.degrees(effectiveScheme == .dark ? 0 : -30))
                .frame(width: 46, height: 46)
                .background(Circle().fill(palette.heading))
                .overlay(Circle().strokeBorder(palette.paper.opacity(0.16), lineWidth: 1))
                .shadow(
                    color: .black.opacity(effectiveScheme == .dark ? 0.55 : 0.18),
                    radius: 14,
                    y: 6
                )
        }
        .buttonStyle(.plain)
        .padding(.trailing, 20)
        .padding(.bottom, 28)
        .accessibilityLabel(effectiveScheme == .dark ? "Switch to light" : "Switch to dark")
        .accessibilityIdentifier("article-appearance-toggle")
    }

    // MARK: - Methods

    private func readingProgress(viewportHeight: CGFloat) -> CGFloat {
        let scrollable = contentHeight - viewportHeight
        guard scrollable > 1 else { return 0 }
        return min(max(-scrollOffset / scrollable, 0), 1)
    }

    /// The running head takes over once the printed headline has scrolled off.
    private var runningTitleOpacity: Double {
        Double(min(max((-scrollOffset - 96) / 56, 0), 1))
    }
}

/// The rendered document, isolated from the scroll-driven state on
/// `ArticleScreen`.
///
/// Reading progress updates `scrollOffset` on every frame of a scroll, which
/// re-evaluates the screen's `body`. Inline, that rebuilt the markdown theme
/// and re-drove `EnrichedMarkdownText` 60 times a second — one core pegged for
/// the length of the gesture. Nothing here depends on the scroll position, so
/// `Equatable` lets SwiftUI skip the whole subtree until the palette or the
/// column width actually changes.
private struct ArticleBody: View, Equatable {
    let markdown: String
    let palette: ArticlePalette
    let figureHeight: CGFloat
    let gutter: CGFloat
    let onLinkPress: (URL) -> Void

    /// The closure is deliberately not compared: it is recreated on every
    /// parent evaluation and only ever writes the alert state.
    static func == (lhs: ArticleBody, rhs: ArticleBody) -> Bool {
        lhs.markdown == rhs.markdown
            && lhs.palette == rhs.palette
            && lhs.figureHeight == rhs.figureHeight
            && lhs.gutter == rhs.gutter
    }

    var body: some View {
        EnrichedMarkdownText(markdown, flags: Md4cFlags(highlight: true))
            .markdownLaTeX()
            .markdownTheme(ArticleMarkdownTheme(palette, figureHeight: figureHeight))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, gutter)
            .padding(.top, 30)
            .padding(.bottom, 4)
            .onLinkPress(onLinkPress)
    }
}

// MARK: -

#Preview {
    NavigationStack {
        ArticleScreen(article: .featured)
    }
}
