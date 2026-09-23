---
sidebar_label: EnrichedMarkdownText
sidebar_position: 1
---

# EnrichedMarkdownText

`EnrichedMarkdownText` renders Markdown as fully native text. It parses with [md4c](https://github.com/mity/md4c) and paints the result through TextKit, so selection, VoiceOver, and Dynamic Type all behave like first-class native text.

```swift
public struct EnrichedMarkdownText: View {
  public init(_ markdown: String, flags: Md4cFlags = .commonMark)
}
```

The initializer takes the document and the parser flags. **Everything else is a view modifier** reading from the SwiftUI environment, so a handler or a theme set on a container applies to every `EnrichedMarkdownText` beneath it:

```swift
ScrollView {
  ForEach(messages) { message in
    EnrichedMarkdownText(message.body)
  }
}
.onLinkPress { UIApplication.shared.open($0) }
.markdownTheme(appTheme)
```

:::note
Parsing and rendering run **off the main thread**, and the result is applied when it lands. A view shows nothing for its first frame or two on a long document, and a superseded render is discarded rather than painted late.
:::

## Parameters

### `markdown`

The Markdown source to render. Which syntax is recognized depends on [`flags`](#flags) - see [Feature support](/introduction/supported-features) for the full matrix and [Element structure](/ios/api-reference/element-structure) for what each element renders as.

An empty or whitespace-only string renders nothing at all, rather than an empty box with the paragraph's margins.

<PropInfo type="String" required />

### `flags`

Toggles for md4c's parser extensions. Each one opts a piece of extra syntax in or out; set only the ones you want to change and the rest keep their defaults.

<PropInfo type="Md4cFlags" default=".commonMark" />

```swift
public struct Md4cFlags: Sendable, Equatable {
  public var underline: Bool            // false
  public var superscript: Bool          // false
  public var `subscript`: Bool          // false
  public var highlight: Bool            // false
  public var hardSoftBreaks: Bool       // false
  public var permissiveAutolinks: Bool  // true
  public var preserveBlankLines: Bool   // false
  public var admonitions: Bool          // false

  public static let commonMark: Md4cFlags
}
```

```swift
EnrichedMarkdownText(content, flags: Md4cFlags(underline: true, admonitions: true))
```

:::note
`.commonMark` turns **everything off except `permissiveAutolinks`**. Tables, task lists, strikethrough, and spoilers are not on this list because they are always enabled - there is no flag to forget.
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
`subscript` and strikethrough share the tilde. With the flag on, `~text~` is a subscript and `~~text~~` is still strikethrough - so a document that uses single tildes as decoration will render them as lowered text instead.
:::

#### `highlight`

Renders `==text==` with a background, styled through [`Highlight()`](/ios/api-reference/style-properties#highlight).

<PropInfo type="Bool" default="false" />

#### `permissiveAutolinks`

Links bare URLs, `www.` hosts, and email addresses. Plain Markdown only autolinks a URL wrapped in angle brackets - `<https://swmansion.com>` - so with this off, a URL pasted on its own stays inert text. With it on, `https://swmansion.com` becomes a link as written.

This is separate from `[text](url)`, which is an ordinary inline link and always works. The flag is the one extension that is **on** by default.

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

### `.onLinkPress` {#onlinkpress}

Called with the `URL` when the reader taps a link. Links do nothing until you handle this - the package never opens a URL on your behalf.

<PropInfo type="(URL) -> Void" default="none" />

```swift
EnrichedMarkdownText(content)
  .onLinkPress { url in
    UIApplication.shared.open(url)
  }
```

### `.onLinkLongPress` {#onlinklongpress}

Called with the `URL` when the reader long-presses a link, **replacing** the system link preview menu - the usual hook for your own share sheet or "copy link" action.

<PropInfo type="(URL) -> Void" default="none" />

A long press resolves in one of three ways, so which modifiers you set decides what the reader gets:

| Set | Long-pressing a link |
| --- | --- |
| `.onLinkLongPress` | Your handler runs; the system menu is suppressed |
| Only `.onLinkPress` | The press handler runs; the system menu is suppressed |
| Neither | The system link preview and menu appear, as in any text view |

There is no separate "enable link preview" switch: the system preview is what you get until a handler takes the interaction over.

## Task lists

### `.onTaskListItemPress` {#ontasklistitempress}

Called after a tap on a task list checkbox toggles the item. Not called when [`.markdownTaskListItemToggleEnabled`](#markdowntasklistitemtoggleenabled) is `false`.

<PropInfo type="(TaskListItemPressEvent) -> Void" default="none" />

```swift
public struct TaskListItemPressEvent: Equatable, Sendable {
  public let index: Int      // 0-based, in document order
  public let checked: Bool   // state after the toggle
  public let text: String    // first line of the item's plain text
}
```

```swift
EnrichedMarkdownText(checklist)
  .onTaskListItemPress { event in
    store.setDone(event.index, event.checked)
  }
```

The toggle is **visual only**. The view never rewrites the `markdown` string you passed it, so persist the change from the handler if it has to survive a new source string. Re-supplying the *same* string keeps the toggles as the reader left them, and so does a theme or Dynamic Type change - the toggle is re-applied on top of the re-render.

### `.markdownTaskListItemToggleEnabled` {#markdowntasklistitemtoggleenabled}

Whether tapping a task list checkbox toggles it. With `false`, checkbox taps are fully inert: no visual toggle and no [`.onTaskListItemPress`](#ontasklistitempress). Text selection and links are unaffected either way.

<PropInfo type="Bool" default="true" />

## Selection and copying

### `.markdownSelectable` {#markdownselectable}

Whether the reader can select and copy text. Links stay tappable when selection is off.

<PropInfo type="Bool" default="true" />

:::note
A document renders into a single text view, so a selection can run across the whole document - headings, quotes, and code blocks included. It cannot span **two** `EnrichedMarkdownText` views, though: each one is its own selection scope.
:::

### `.markdownSelectionColor` {#markdownselectioncolor}

Tints the selection highlight, the drag handles, and the caret. UIKit derives all three from one tint, so they cannot be colored separately. `nil` keeps the system tint.

<PropInfo type="Color?" default="nil" />

### `.markdownSelectionMenu` {#markdownselectionmenu}

Configures the two items the package adds to the text selection edit menu. The system's own items - Copy, Look Up, Translate, Share - are untouched.

These two are the only additions available: there is no hook for contributing your own menu items yet, and no switch for the long-press menu on a table. Custom context-menu items are on the [roadmap](/misc/roadmap#native-renderer-parity).

<PropInfo type="MarkdownSelectionMenuConfig" default="MarkdownSelectionMenuConfig()" />

```swift
public struct MarkdownSelectionMenuConfig: Equatable, Sendable {
  public init(
    copyAsMarkdown: Bool = true,
    copyImageUrl: Bool = true,
    copyAsMarkdownLabel: String = "Copy as Markdown"
  )
}
```

#### `copyAsMarkdown`

Adds an item that puts the selection on the pasteboard as **Markdown source**. A selection covering the whole document copies the original string verbatim; a partial selection is reconstructed from the rendered text, markers and all.

<PropInfo type="Bool" default="true" />

#### `copyImageUrl`

Adds an item that copies the `http(s)` URLs of any images inside the selection, one per line. It appears only when the selection actually contains one, and its title counts them - *Copy Image URL*, *Copy 3 Image URLs*.

<PropInfo type="Bool" default="true" />

#### `copyAsMarkdownLabel`

The title of the Copy as Markdown item - the hook for localizing it.

<PropInfo type="String" default='"Copy as Markdown"' />

```swift
EnrichedMarkdownText(content)
  .markdownSelectionMenu(
    MarkdownSelectionMenuConfig(
      copyImageUrl: false,
      copyAsMarkdownLabel: "Als Markdown kopieren"
    )
  )
```

:::note
Recent iOS versions stop offering **Select All** on non-editable text views, which would leave no way to grow a long-press selection to the whole document. The package supplies its own item when the system omits it. Its title is English and is not configurable.
:::

### What the system Copy puts on the pasteboard {#copy-flavors}

The system **Copy** item writes the selection in two flavors at once: plain text, and styled HTML (`public.html`). Rich text targets - Mail, Notes, a web editor - pick up the HTML and keep headings, inline styles, lists, quotes, code blocks, links, and images; plain text targets get plain text. A table inside the selection becomes tab-separated columns in the plain flavor and a real `<table>` in the HTML one.

For the Markdown source instead, use the Copy as Markdown item above. See [Copy options](/user-experience/copy-options) for more on what each action puts on the pasteboard.

## Spoilers

### `.markdownSpoilerOverlay` {#markdownspoileroverlay}

Chooses how `||spoiler||` text is concealed until it is tapped.

<PropInfo type="MarkdownSpoilerOverlay" default=".particles" />

```swift
public enum MarkdownSpoilerOverlay: Equatable, Sendable {
  case particles   // animated dot field, the default
  case solid       // rounded box
}
```

Spoiler syntax is always parsed - there is no flag to enable. Colors and sizing come from the [`Spoiler()`](/ios/api-reference/style-properties#spoiler) element.

Behavior worth knowing:

- One spoiler reveals at a time, and a revealed one **stays revealed** across a theme or Dynamic Type change. Changing the `markdown` string conceals them all again.
- A link inside a concealed spoiler is not a link: no tap, no long press, no menu, and no VoiceOver link element until the spoiler is revealed.
- Copying reproduces the `||` markers whether or not the spoiler was revealed, and VoiceOver reads spoiler text as ordinary text.

## Images

### `.markdownImageRequestHeaders` {#markdownimagerequestheaders}

HTTP headers attached to **remote** image requests - an `Authorization` token, a `Referer`, and so on. They apply to every image the document loads.

<PropInfo type="[String: String]" default="[:]" />

```swift
EnrichedMarkdownText(content)
  .markdownImageRequestHeaders(["Authorization": "Bearer \(token)"])
```

Headers take part in the cache key, so the same URL fetched with different headers is cached and deduplicated separately - see [Images and caching](/ios/guides/image-caching).

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
| `list.nested.*` | The same four, prefixed `"Nested "` |
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
