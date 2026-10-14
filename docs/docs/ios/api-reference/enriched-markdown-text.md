---
sidebar_label: EnrichedMarkdownText
sidebar_position: 1
---

# EnrichedMarkdownText

`EnrichedMarkdownText` renders Markdown as fully native text. It parses with [md4c](https://github.com/mity/md4c) and paints the result through TextKit, so selection, VoiceOver, and Dynamic Type all behave like first-class native text.

```swift
public struct EnrichedMarkdownText: View {
  public init(_ markdown: String, options: MarkdownParsingOptions = .commonMark)
}
```

The initializer takes the document and the parser options. **Everything else is a view modifier** reading from the SwiftUI environment, so a handler or a theme set on a container applies to every `EnrichedMarkdownText` beneath it:

```swift
ScrollView {
  ForEach(messages) { message in
    EnrichedMarkdownText(message.body)
  }
}
.environment(\.openURL, OpenURLAction { url in
  route(url)
  return .handled
})
.markdownTheme(appTheme)
```

:::note
Parsing and rendering run **off the main thread**, and the result is applied when it lands. Every render goes this way, the first one included, so a new view is blank for its first frame or two however short the document is - longer on a long one. A superseded render is discarded rather than painted late.
:::

## Parameters

### `markdown`

The Markdown source to render. Which syntax is recognized depends on [`options`](#options) - see [Feature support](/introduction/supported-features) for the full matrix and [Element structure](/ios/api-reference/element-structure) for what each element renders as.

An empty or whitespace-only string renders nothing at all, rather than an empty box with the paragraph's margins.

<PropInfo type="String" required />

```swift
EnrichedMarkdownText(article.body)

EnrichedMarkdownText("# Inline\n\nA **bold** word and a [link](https://swmansion.com).")
```

### `options` {#options}

Toggles for md4c's parser extensions. Each one opts a piece of extra syntax in or out; set only the ones you want to change and the rest keep their defaults.

<PropInfo type="MarkdownParsingOptions" default=".commonMark" />

```swift
public struct MarkdownParsingOptions: Sendable, Equatable {
  public var underline: Bool            // false
  public var superscript: Bool          // false
  public var `subscript`: Bool          // false
  public var highlight: Bool            // false
  public var hardSoftBreaks: Bool       // false
  public var permissiveAutolinks: Bool  // true
  public var preserveBlankLines: Bool   // false
  public var admonitions: Bool          // false

  public static let commonMark: MarkdownParsingOptions
}
```

```swift
EnrichedMarkdownText(content, options: MarkdownParsingOptions(underline: true, admonitions: true))
```

:::note
`.commonMark` turns **everything off except `permissiveAutolinks`**. Tables, task lists, strikethrough, and spoilers are not on this list because they are always enabled - there is no option to forget.
:::

For a walkthrough of what each extension changes, see [Parser extensions](/ios/guides/parser-extensions).

#### `underline`

Renders `_text_` and `__text__` as underlined instead of italic and bold. Style it through the [`Underline()`](/ios/api-reference/style-properties#underline) element.

<PropInfo type="Bool" default="false" />

#### `superscript`

Renders `^text^` raised above the baseline. Style it through [`Superscript()`](/ios/api-reference/style-properties#superscript--subscript).

<PropInfo type="Bool" default="false" />

#### `subscript`

Renders `~text~` lowered below the baseline. Style it through [`Subscript()`](/ios/api-reference/style-properties#superscript--subscript).

<PropInfo type="Bool" default="false" />

:::caution
`subscript` and strikethrough share the tilde. With the option off, a single-tilde `~text~` is **strikethrough**, the same as `~~text~~`. Turning it on changes what single tildes mean: `~text~` becomes a subscript and only `~~text~~` stays struck through - so a document that strikes text out with single tildes renders it lowered instead.
:::

#### `highlight`

Renders `==text==` with a background, styled through [`Highlight()`](/ios/api-reference/style-properties#highlight).

<PropInfo type="Bool" default="false" />

#### `permissiveAutolinks`

Links bare URLs, `www.` hosts, and email addresses. Plain Markdown only autolinks a URL wrapped in angle brackets - `<https://swmansion.com>` - so with this off, a URL pasted on its own stays inert text. With it on, `https://swmansion.com` becomes a link as written.

This is separate from `[text](url)`, which is an ordinary inline link and always works. This is the one extension that is **on** by default.

<PropInfo type="Bool" default="true" />

#### `hardSoftBreaks`

Treats a single newline as a hard line break, so lines inside one paragraph keep the breaks you typed instead of reflowing. See [Line breaks](/ios/api-reference/element-structure#line-breaks).

<PropInfo type="Bool" default="false" />

#### `preserveBlankLines`

Keeps consecutive blank lines instead of collapsing them, so vertical whitespace in the source survives into the output.

<PropInfo type="Bool" default="false" />

#### `admonitions`

Renders a blockquote whose first line is `> [!NOTE]`, `> [!TIP]`, `> [!IMPORTANT]`, `> [!WARNING]`, or `> [!CAUTION]` as a themed callout with an icon and a title. Without it the marker stays literal text inside an ordinary quote. Colors come from the [`Admonition()`](/ios/api-reference/style-properties#admonition) element.

<PropInfo type="Bool" default="false" />

## Links

### `openURL` {#openurl}

Link taps go through SwiftUI's own `openURL` environment action, exactly as the links in a plain `Text` do. With nothing installed the system opens the URL, which is the ordinary case; install an `OpenURLAction` to route taps yourself.

<PropInfo type="OpenURLAction" default="the system action" />

```swift
EnrichedMarkdownText(content)
  .environment(\.openURL, OpenURLAction { url in
    guard url.host == "myapp.example" else { return .systemAction }
    navigate(to: url)
    return .handled
  })
```

Because it reads from the environment, one action set on a container covers every `EnrichedMarkdownText` beneath it.

Return `.handled` to take the tap over, or `.systemAction` to hand the URL back to the system - which is how you intercept your own deep links while letting every other link open normally.

### `.onMarkdownLinkLongPress` {#onmarkdownlinklongpress}

Called with the `URL` when the reader long-presses a link, **replacing** the system link preview menu - the usual hook for your own share sheet or "copy link" action.

<PropInfo type="(URL) -> Void" default="none" />

| Set | Long-pressing a link |
| --- | --- |
| `.onMarkdownLinkLongPress` | Your handler runs; the system menu is suppressed |
| Nothing | The system link preview and menu appear, as in any text view |

```swift
EnrichedMarkdownText(content)
  .onMarkdownLinkLongPress { url in
    shareSheet(for: url)   // replaces the system preview
  }
```

There is no separate "enable link preview" switch: the system preview is what you get until a long-press handler takes the interaction over. A tap and a long press are independent - installing an [`openURL`](#openurl) action does not suppress the preview menu.

## Task lists

### `.onTaskListItemToggle` {#ontasklistitemtoggle}

Called after a tap on a task list checkbox toggles the item. Not called when [`.markdownTaskListItemToggleEnabled`](#markdowntasklistitemtoggleenabled) is `false`.

<PropInfo type="(TaskListItemToggle) -> Void" default="none" />

```swift
public struct TaskListItemToggle: Equatable, Sendable {
  public let index: Int       // 0-based, in document order
  public let isChecked: Bool  // state after the toggle
  public let text: String     // first line of the item's plain text
}
```

```swift
EnrichedMarkdownText(checklist)
  .onTaskListItemToggle { item in
    store.setDone(item.index, item.isChecked)
  }
```

The toggle **never writes back to your state**: the `markdown` string you passed in is left exactly as it was, so persist the change from the handler if it has to survive a **new** source string. The view does keep its own toggled copy of the source, which is what re-renders parse - so re-supplying the *same* string keeps the toggles as the reader left them, and so does a theme or Dynamic Type change. That copy is also what [Copy as Markdown](#markdownselectionmenu) serializes, so copying an item the reader checked yields `- [x]` rather than the `- [ ]` you supplied.

### `.markdownTaskListItemToggleEnabled` {#markdowntasklistitemtoggleenabled}

Whether tapping a task list checkbox toggles it. With `false`, checkbox taps are fully inert: no visual toggle and no [`.onTaskListItemToggle`](#ontasklistitemtoggle). Text selection and links are unaffected either way.

<PropInfo type="Bool" default="true" />

```swift
// A read-only checklist: boxes render checked or not, but do not respond.
EnrichedMarkdownText(checklist)
  .markdownTaskListItemToggleEnabled(false)
```

## Selection and copying

### `.markdownTextSelection` {#markdowntextselection}

Whether the reader can select and copy text. Links stay tappable when selection is off.

<PropInfo type="some TextSelectability" default=".enabled" />

```swift
EnrichedMarkdownText(content)
  .markdownTextSelection(.disabled)
```

It takes SwiftUI's own `TextSelectability`, the same `.enabled` / `.disabled` values as `.textSelection(_:)`, so it reads like the rest of a SwiftUI view tree. `.enabled` and `.disabled` are two **different** types, though - as they are for SwiftUI's own modifier - so a stored `Bool` cannot choose between them with a ternary. Branch in the view body instead.

:::note
A document renders into a single text view, so a selection can run across the whole document - headings, quotes, and code blocks included. It cannot span **two** `EnrichedMarkdownText` views, though: each one is its own selection scope.
:::

### `.markdownSelectionColor` {#markdownselectioncolor}

Tints the selection highlight, the drag handles, and the caret. UIKit derives all three from one tint, so they cannot be colored separately. `nil` keeps the system tint.

<PropInfo type="Color?" default="nil" />

```swift
EnrichedMarkdownText(content)
  .markdownSelectionColor(.orange)

EnrichedMarkdownText(content)
  .markdownSelectionColor(nil)   // back to the system tint
```

### `.markdownSelectionMenu` {#markdownselectionmenu}

Configures the two items the package adds to the text selection edit menu. The system's own items - Copy, Look Up, Translate, Share - are untouched.

These two are the only additions available: there is no hook for contributing your own menu items yet, and no switch for the long-press menu on a table. Custom context-menu items are on the [roadmap](/misc/roadmap).

<PropInfo type="MarkdownSelectionMenu" default="MarkdownSelectionMenu()" />

```swift
public struct MarkdownSelectionMenu: Equatable, Sendable {
  public init(
    copyAsMarkdown: Bool = true,
    copyImageURL: Bool = true,
    copyAsMarkdownLabel: String = "Copy as Markdown"
  )
}
```

#### `copyAsMarkdown`

Adds an item that puts the selection on the pasteboard as **Markdown source**. A selection covering the whole document copies the original string verbatim. A partial selection copies the matching **slice of your source** where it can - widened to take in the markers, list prefixes, and fences the selection visually includes, and checked by re-parsing it. Only when no slice matches is the Markdown reconstructed from the rendered text instead.

<PropInfo type="Bool" default="true" />

#### `copyImageURL`

Adds an item that copies the URLs of any images inside the selection, one per line. It appears only when the selection actually contains one, and its title counts them - *Copy Image URL*, *Copy 3 Image URLs*.

<PropInfo type="Bool" default="true" />

#### `copyAsMarkdownLabel`

The title of the Copy as Markdown item - the hook for localizing it.

<PropInfo type="String" default='"Copy as Markdown"' />

```swift
EnrichedMarkdownText(content)
  .markdownSelectionMenu(
    MarkdownSelectionMenu(
      copyImageURL: false,
      copyAsMarkdownLabel: "Als Markdown kopieren"
    )
  )
```

:::note
Recent iOS versions stop offering **Select All** on non-editable text views, which would leave no way to grow a long-press selection to the whole document. The package supplies its own item when the system omits it. Its title is English and is not configurable.
:::

### What the system Copy puts on the pasteboard {#copy-flavors}

The system **Copy** item writes the selection in two flavors at once: plain text, and styled HTML (`public.html`). Rich text targets - Mail, Notes, a web editor - pick up the HTML and keep headings, inline styles, lists, quotes, code blocks, links, and images; plain text targets get plain text. A table inside the selection becomes tab-separated columns in the plain flavor and a real `<table>` in the HTML one.

```swift
// Reading what the reader just copied, after a system Copy:
let plain = UIPasteboard.general.string
let html = UIPasteboard.general.data(forPasteboardType: "public.html")
```

For the Markdown source instead, use the Copy as Markdown item above. See [Copy options](/user-experience/copy-options) for more on what each action puts on the pasteboard.

## Spoilers

### `.markdownSpoilerOverlay` {#markdownspoileroverlay}

Chooses how `||spoiler||` text is concealed until it is tapped.

<PropInfo type="any SpoilerOverlayProvider" default=".particles" />

```swift
import EnrichedMarkdown
import SwiftUI

EnrichedMarkdownText(content)
  .markdownSpoilerOverlay(.solid)

EnrichedMarkdownText(content)
  .markdownSpoilerOverlay(.particles(density: 12, speed: 30))
```

| Provider | Draws |
| --- | --- |
| `.particles` | The default: a field of drifting dots over an opaque backdrop |
| `.particles(density:speed:)` | The same, tuned. `density` is particles per 100×100 pt (default `8`), `speed` is drift in points per second (default `20`) - absolute values, not multipliers |
| `.solid` | An opaque box with 4 pt corners |
| `.solid(cornerRadius:)` | The same box with your corner radius, in points |

Spoiler syntax is always parsed - there is no option to enable. The provider chooses **which** overlay is drawn and how it behaves; its **colors** - the particles or box fill, and the backdrop under the particles - come from the [`Spoiler()`](/ios/api-reference/style-properties#spoiler) theme element. To draw an effect of your own, see [Custom spoiler overlays](#custom-spoiler-overlays).

Behavior worth knowing:

- A tap reveals **only the spoiler under it**; the others stay concealed, and any number can be open at once. A revealed spoiler **stays revealed** across a theme or Dynamic Type change. Changing the `markdown` string conceals them all again.
- A link inside a concealed spoiler is not a link: no tap, no long press, no menu, and no VoiceOver link element until the spoiler is revealed.
- The system **Copy** puts the spoiler's text on the pasteboard as ordinary text, concealed or not - a selection that spans a spoiler gives its content away. Only [Copy as Markdown](#markdownselectionmenu) keeps the `||` markers.
- VoiceOver reads spoiler text as ordinary text.

### Custom spoiler overlays {#custom-spoiler-overlays}

A custom effect is two pieces: a `SpoilerOverlayProvider` that you pass to `.markdownSpoilerOverlay`, and the `SpoilerOverlayView` subclass it builds.

```swift
public protocol SpoilerOverlayProvider: Equatable, Sendable {
  @MainActor
  func makeOverlay(charRange: NSRange, style: SpoilerStyle) -> SpoilerOverlayView
}

open class SpoilerOverlayView: UIView {
  public init(charRange: NSRange)

  public let charRange: NSRange                        // the whole spoiler, shared by its segments
  public internal(set) var concealedText: NSAttributedString  // this segment's text, styled
  public internal(set) var baseline: CGFloat           // the line's baseline, from the view's top
  public internal(set) var segmentIndex: Int           // this segment, in reading order
  public internal(set) var segmentCount: Int
  public internal(set) var revealPoint: CGPoint?       // the tap, in this view's coordinates

  public func concealedTextImage(_ text: NSAttributedString? = nil) -> UIImage
  open func animateReveal(completion: @escaping () -> Void)
}
```

The text view calls `makeOverlay` once per **line segment** of a spoiler - one that wraps onto three lines gets three views - then sets the view's frame and the properties above and adds it over the text. `style` is the resolved [`Spoiler()`](/ios/api-reference/style-properties#spoiler) theme element, so an effect can take its colors from the theme like the built-ins do.

```swift
import EnrichedMarkdown
import SwiftUI
import UIKit

/// An opaque bar that slides away line by line when tapped.
struct WipeSpoilerOverlay: SpoilerOverlayProvider {
  var cornerRadius: CGFloat = 3
  var lineDelay: TimeInterval = 0.12

  @MainActor
  func makeOverlay(charRange: NSRange, style: SpoilerStyle) -> SpoilerOverlayView {
    WipeSpoilerOverlayView(
      charRange: charRange,
      color: style.color ?? .secondaryLabel,
      cornerRadius: cornerRadius,
      lineDelay: lineDelay
    )
  }
}

final class WipeSpoilerOverlayView: SpoilerOverlayView {
  private let lineDelay: TimeInterval

  init(charRange: NSRange, color: UIColor, cornerRadius: CGFloat, lineDelay: TimeInterval) {
    self.lineDelay = lineDelay
    super.init(charRange: charRange)
    backgroundColor = color          // opaque: see below
    layer.cornerRadius = cornerRadius
  }

  override func animateReveal(completion: @escaping () -> Void) {
    UIView.animate(
      withDuration: 0.3,
      delay: lineDelay * Double(segmentIndex),
      options: .curveEaseIn
    ) {
      self.transform = CGAffineTransform(translationX: self.bounds.width, y: 0)
      self.alpha = 0
    } completion: { _ in
      completion()                   // required: the view is removed only now
    }
  }
}

EnrichedMarkdownText(content)
  .markdownSpoilerOverlay(WipeSpoilerOverlay(lineDelay: 0.2))
```

The contract:

- **The view must be opaque.** The text under a concealed spoiler is drawn transparent, but emoji and inline images ignore that and would show through a see-through overlay. Give the view a solid background, as the built-in particles do with their backdrop. An effect that should show the text through - a blur, a shimmer over the letters - draws `concealedTextImage()` itself: `concealedText` rendered on a transparent canvas the size of the view, positioned as the text view lays it out.
- **`animateReveal(completion:)` must call `completion`.** A reveal calls it on every segment of the spoiler at once, and each view is removed from the text view only when its completion runs - one that never calls it stays on screen. The default fades `alpha` out; call `super` to keep that fade under your own animation. `revealPoint` says where the reader tapped, and is `nil` for a programmatic reveal and outside the bounds when the tap landed on another segment of the same spoiler. `segmentIndex` and `segmentCount` are what a wrapped spoiler needs to reveal in reading order.
- **Keep the provider `Equatable` through its stored properties.** The text view rebuilds its overlays only when the provider value changes, so let Swift synthesize `==` from the parameters - a provider that compares equal while drawing something different is never rebuilt.
- **Keep construction cheap.** When a re-layout only moves a segment, its view moves with it and keeps its state; when the segment's text, size, or baseline changes, the view is thrown away and `makeOverlay` called again.

## Code blocks

### `.markdownCodeBlockLayout` {#markdowncodeblocklayout}

Lays fenced code blocks out as wrapping text, or as panels with a language header and a copy button whose lines keep their length and scroll sideways.

<PropInfo type="MarkdownCodeBlockLayout" default=".wrapping" />

```swift
public enum MarkdownCodeBlockLayout: Equatable, Sendable {
  case wrapping    // lines break at the view's width; the code is selectable text
  case scrollable  // a panel: language name and copy button above lines kept whole
}

EnrichedMarkdownText(content)
  .markdownCodeBlockLayout(.scrollable)
```

A `.scrollable` panel names the language from the fence (`py` reads "Python"; an unknown info string is shown capitalized), and a block wider than the view scrolls sideways in place. Long-pressing a panel offers **Copy** and **Copy as Markdown**. Text selection treats the panel as one character: a selection spanning it copies the code as plain text and a `<pre>` in the HTML flavor, and Copy as Markdown restores the fence. VoiceOver reads the panel as one element with the "Copy code" action, as it does a wrapping block.

A rightward pan on a panel already at its left edge is left to the system, so a full-width back gesture still works; tables and display math behave the same way.

Both layouts take their font, colors, padding, corner radius, border and margins from the [`CodeBlock()`](/ios/api-reference/style-properties#codeblock) theme element; its `.headerForegroundStyle(_:)` tints the panel's label and copy button.

Code is drawn in one color by default. To color it by language, add the `EnrichedMarkdownSyntaxHighlighting` product and apply `.markdownSyntaxHighlighting()` - see [Syntax highlighting](/ios/guides/syntax-highlighting).

### `.onCodeBlockCopy` {#oncodeblockcopy}

Called after a code block's code is copied: by a panel's copy button, its long-press **Copy**, or the VoiceOver "Copy code" action in either layout. Not called for Copy as Markdown.

<PropInfo type="(CodeBlockCopy) -> Void" default="none" />

```swift
public struct CodeBlockCopy: Equatable, Sendable {
  public let code: String
  public let language: String?  // the fence's info string, nil when it named none
}

EnrichedMarkdownText(content)
  .markdownCodeBlockLayout(.scrollable)
  .onCodeBlockCopy { copy in
    print("Copied \(copy.code.count) characters of \(copy.language ?? "plain") code")
  }
```

## Images

### `.markdownImageRequestHeaders` {#markdownimagerequestheaders}

HTTP headers attached to **remote** image requests - an `Authorization` token, a `Referer`, and so on. They apply to every image the document loads.

<PropInfo type="[String: String]" default="[:]" />

```swift
EnrichedMarkdownText(content)
  .markdownImageRequestHeaders(["Authorization": "Bearer \(token)"])
```

Headers take part in the cache key, so the same URL fetched with different headers is cached and deduplicated separately - see [Images and caching](/ios/guides/image-caching).

## Layout

### `.markdownWritingDirection` {#markdownwritingdirection}

Sets how each paragraph's base writing direction is resolved - which side its text starts from, and so which side its list marker, checkbox, and blockquote bar sit on. The default handles a document that mixes left-to-right and right-to-left paragraphs without any configuration.

<PropInfo type="MarkdownWritingDirection" default=".firstStrong" />

```swift
public enum MarkdownWritingDirection: CaseIterable, Equatable, Sendable {
  case firstStrong  // each paragraph follows its first strong directional character
  case natural      // direction is left to TextKit
  case leftToRight  // every paragraph left-to-right
  case rightToLeft  // every paragraph right-to-left
}
```

```swift
import EnrichedMarkdown
import SwiftUI

EnrichedMarkdownText(content)
  .markdownWritingDirection(.rightToLeft)
```

| Case | Each paragraph runs |
| --- | --- |
| `.firstStrong` | In the direction of its first strong character - a Hebrew or Arabic letter makes it right-to-left, a Latin one left-to-right. A paragraph with no strong character (only digits or punctuation) follows the SwiftUI `layoutDirection` environment value |
| `.natural` | As TextKit decides. List markers, checkboxes, blockquote bars, and paragraphs with no strong character follow the app's interface direction rather than the paragraph's |
| `.leftToRight` | Left-to-right, whatever its text |
| `.rightToLeft` | Right-to-left, whatever its text |

Under every case other than `.natural`, a paragraph's decorations follow that paragraph: a right-to-left list item has its marker or checkbox on the right, a right-to-left quote its bar on the right, even in a left-to-right app. An admonition's title takes the direction of the body it introduces. **Code blocks always render left-to-right**, whichever case is set.

### `.markdownBottomMargin` {#markdownbottommargin}

Whether the last block's bottom margin is laid out below the text. Hidden by default: the view ends at its last line, so the gap between it and whatever follows is the container's to decide - a `VStack` spacing, a `padding`, a list row inset - rather than the theme's. Show it for a view that should hold its own gap, such as one ending a scrolling column.

<PropInfo type="Visibility" default=".automatic" />

```swift
VStack(spacing: 0) {
  EnrichedMarkdownText(intro)
    .markdownBottomMargin(.visible)   // keeps the paragraph margin below the last line
  Divider()
}
```

It takes SwiftUI's own `Visibility`, as `.listRowSeparator(_:)` and `.scrollContentBackground(_:)` do. `.automatic` and `.hidden` both end the view at its last line.

The margin shown is the one the theme gives the block that ends the document - [`Paragraph().marginBottom(_:)`](/ios/api-reference/style-properties#paragraph) for a paragraph, `Heading(1).marginBottom(_:)` for a heading, and so on. For a top-level block that is the same gap the theme puts between blocks inside the document. Where blocks nest, the largest margin ending the document wins: a code block that closes a list item keeps the list's margin if that is the larger. A code block ending the document keeps its bottom padding either way; only the margin below it is in question.

## Accessibility

### `.markdownAccessibilityLabels` {#markdownaccessibilitylabels}

Overrides the strings VoiceOver speaks. Every field defaults to English, so set only what you localize.

<PropInfo type="MarkdownAccessibilityLabels" default=".default" />

```swift
public struct MarkdownAccessibilityLabels: Equatable, Sendable {
  public var list: List             // top / nested, each with bulletPoint,
                                    // orderedItem, checkedTask, uncheckedTask
  public var blockquote: Blockquote // quote, nestedQuote
  public var table: Table           // row
  public var image: Image           // fallback, for an image with no alt text
  public var codeBlock: CodeBlock   // copy, the custom action's name
  public var rotor: Rotor           // headings, links, images

  public static let `default`: MarkdownAccessibilityLabels
}
```

| Field | Default |
| --- | --- |
| `list.top.bulletPoint` | `"Bullet point"` |
| `list.top.orderedItem` | `"List item {n}"` |
| `list.top.checkedTask` | `"Task, checked"` |
| `list.top.uncheckedTask` | `"Task, not checked"` |
| `list.nested.bulletPoint` | `"Nested bullet point"` |
| `list.nested.orderedItem` | `"Nested list item {n}"` |
| `list.nested.checkedTask` | `"Nested task, checked"` |
| `list.nested.uncheckedTask` | `"Nested task, not checked"` |
| `blockquote.quote` | `"Blockquote"` |
| `blockquote.nestedQuote` | `"Nested blockquote"` |
| `table.row` | `"Row {n}: {content}"` |
| `image.fallback` | `"Image"` |
| `codeBlock.copy` | `"Copy code"` |
| `rotor.headings` / `rotor.links` / `rotor.images` | `"Headings"` / `"Links"` / `"Images"` |

`{n}` is a 1-based index and `{content}` a table row's comma-joined cell text; a translation has to keep the placeholder names. The defaults use the cardinal form - "List item 2", not "2nd item" - so one template works in every language without plural rules.

```swift
var labels = MarkdownAccessibilityLabels()
labels.list.top.bulletPoint = "Punkt"
labels.list.top.orderedItem = "Listenelement {n}"
labels.rotor.headings = "Überschriften"

EnrichedMarkdownText(content)
  .markdownAccessibilityLabels(labels)
```

The label for a formula is not here - it is a parameter of `.markdownLaTeX`, because the math module owns it. See [LaTeX math](/ios/guides/latex-math#accessibility).

For what VoiceOver announces for each element, see [Accessibility](/user-experience/accessibility).

## Theming

### `.markdownTheme` {#markdowntheme}

Provides a `MarkdownTheme` for the subtree. Themes layer, innermost last. It has its own page: [`MarkdownTheme`](/ios/api-reference/markdown-theme).

<PropInfo type="MarkdownTheme" default="MarkdownTheme.default" />

```swift
Content()
  .markdownTheme(appTheme)

EnrichedMarkdownText(content)
  .markdownTheme { Link().foregroundStyle(.red) }
```

## See also

- [Style properties](/ios/api-reference/style-properties) - every styleable element and modifier.
- [`MarkdownTheme`](/ios/api-reference/markdown-theme) - providing and layering themes.
- [Element structure](/ios/api-reference/element-structure) - what each Markdown construct renders as.
