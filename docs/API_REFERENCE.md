# API Reference

## EnrichedMarkdownText

### Props

### `markdown`

The Markdown content to render.

| Type     | Default Value | Platform |
| -------- | ------------- | -------- |
| `string` | Required      | Both     |

### `markdownStyle`

Style configuration for Markdown elements. See the [Style Properties Reference](STYLES.md) for a detailed overview of all available style properties.

| Type             | Default Value | Platform |
| ---------------- | ------------- | -------- |
| `MarkdownStyle`  | `{}`          | Both     |

### `containerStyle`

Style for the container view.

| Type          | Default Value | Platform |
| ------------- | ------------- | -------- |
| `ViewStyle`   | -             | Both     |

### `onLinkPress`

Callback when a link is pressed. Access URL via `event.url`.

| Type                                    | Default Value | Platform |
| --------------------------------------- | ------------- | -------- |
| `(event: LinkPressEvent) => void`       | -             | Both     |

> **Note:** For handling long-press gestures on links, see [`onLinkLongPress`](#onlinklongpress). On iOS, providing `onLinkLongPress` automatically disables the system link preview.

**Example:**

```tsx
<EnrichedMarkdownText
  markdown="Check out [React Native](https://reactnative.dev)!"
  onLinkPress={({ url }) => {
    Alert.alert('Link pressed', url);
    Linking.openURL(url);
  }}
/>
```

### `onLinkLongPress`

Callback when a link is long pressed. Access URL via `event.url`. On iOS, automatically disables the system link preview.

| Type                                         | Default Value | Platform |
| -------------------------------------------- | ------------- | -------- |
| `(event: LinkLongPressEvent) => void`       | -             | Both     |

**Example:**

```tsx
<EnrichedMarkdownText
  markdown="Check out [React Native](https://reactnative.dev)!"
  onLinkLongPress={({ url }) => {
    Alert.alert('Link long pressed', url);
  }}
/>
```

### `onImagePress`

Callback when a rendered image is tapped or clicked. Access the image URL via `event.url` and its Markdown alt text via `event.altText` (`""` when the image has no alt text). Use it to open a lightbox or full-screen viewer.

Fires for block and inline images, including images inside headings, lists, and blockquotes. An image that is also a link (`[![alt](img)](dest)`) keeps link behavior and fires [`onLinkPress`](#onlinkpress) instead, so a single tap never fires both. Not fired for images inside GFM tables.

Setting this callback makes images interactive on the native side; leaving it unset keeps the existing tap, text-selection, and long-press menu behavior unchanged. On web the image becomes focusable, exposes a button role for screen readers, and can be activated with Enter/Space, while the browser's right-click menu is preserved.

| Type                                  | Default Value | Platform         |
| ------------------------------------- | ------------- | ---------------- |
| `(event: ImagePressEvent) => void`    | -             | Both, macOS, Web |

**Example:**

```tsx
<EnrichedMarkdownText
  markdown="![A cat](https://example.com/cat.png)"
  onImagePress={({ url, altText }) => openLightbox({ url, altText })}
/>
```

### `onTaskListItemPress`

Callback when a task list checkbox is tapped. Receives `index` (0-based), `checked` (new state after toggling), and `text` (item text).

| Type                                            | Default Value | Platform |
| ----------------------------------------------- | ------------- | -------- |
| `(event: TaskListItemPressEvent) => void`      | -             | Both     |

### `enableTaskListItemToggle`

Controls whether tapping a task list checkbox toggles its checked state.

When `false`, the checkbox renders its markdown state read-only and the tap is **fully inert** — there is no visual toggle and `onTaskListItemPress` does not fire. Text selection and links in the same row are unaffected.

| Type      | Default Value | Platform          |
| --------- | ------------- | ----------------- |
| `boolean` | `true`        | Both, Web         |

**Example:**

```tsx
// Render checkboxes that reflect the markdown but cannot be toggled by the user
<EnrichedMarkdownText
  markdown={content}
  flavor="github"
  enableTaskListItemToggle={false}
/>
```

> **Note:** On web the checkbox keeps its normal appearance and is marked `readOnly` / `aria-disabled` rather than `disabled`, so it stays visually consistent with iOS and Android. It is also made pointer-inert (`pointer-events: none`), so the browser paints no hover or active state on a checkbox that cannot be toggled.

### `onCopyPress`

Callback when code is copied from a fenced code block, via the header copy button, the long-press context-menu **Copy** action, or the VoiceOver copy action. Receives `code` (the copied code) and `language` (the fence language, or `""` if none). Does not fire for **Copy as Markdown**.

Only fires when `flavor="github"` — the copy button is part of the GitHub flavor's code block renderer.

| Type                                  | Default Value | Platform         |
| ------------------------------------- | ------------- | ---------------- |
| `(event: CopyPressEvent) => void`     | -             | Both, macOS      |

**Example:**

```tsx
<EnrichedMarkdownText
  flavor="github"
  markdown={"```ts\nconst x = 1;\n```"}
  onCopyPress={({ code, language }) => {
    console.log(`Copied ${language} code:`, code);
  }}
/>
```

### `enableBlockContextMenu`

Controls the long-press copy popup on code blocks, tables, and block math.
Setting it to `false` leaves the code-block header copy button, accessibility
copy action, and system text-selection menu unchanged.

| Type      | Default Value | Platform            |
| --------- | ------------- | ------------------- |
| `boolean` | `true`        | iOS, Android, macOS |

```tsx
<EnrichedMarkdownText
  flavor="github"
  markdown={content}
  enableBlockContextMenu={false}
/>
```

### `enableLinkPreview`

Controls the native link preview on long press (iOS only). Automatically set to `false` when `onLinkLongPress` is provided.

| Type      | Default Value | Platform |
| --------- | ------------- | -------- |
| `boolean` | `true`         | iOS      |

By default, long-pressing a link on iOS shows the native system link preview. When you provide `onLinkLongPress`, the system preview is automatically disabled so your handler can fire instead.

You can also control this behavior explicitly without providing a handler:

```tsx
// Disable system link preview without providing a handler
<EnrichedMarkdownText
  markdown={content}
  enableLinkPreview={false}
/>
```

### `selectable`

Whether text can be selected.

| Type      | Default Value | Platform |
| --------- | ------------- | -------- |
| `boolean` | `true`         | Both     |

### `selectionColor`

Color of the text selection highlight. On iOS, this also affects the caret and selection handle colors (they share a single tint). On macOS, only the selection background is affected. On Android, use `selectionHandleColor` to override the handle color independently.

| Type         | Default Value | Platform           |
| ------------ | ------------- | ------------------ |
| `ColorValue` | -             | Both, macOS, Web   |

### `selectionHandleColor`

Color of the selection handles (drag anchors). No-op on Android API levels below 29.

| Type         | Default Value | Platform |
| ------------ | ------------- | -------- |
| `ColorValue` | -             | Android  |

### `md4cFlags`

Configuration for md4c parser extension flags.

| Type          | Default Value            | Platform |
| ------------- | ------------------------ | -------- |
| `Md4cFlags`   | `{ underline: false, superscript: false, subscript: false, highlight: false, latexMath: true, hardSoftBreaks: false, preserveBlankLines: false }` | Both |

**Properties:**

- **`underline`**: When `true`, treats `_text_` as underline instead of emphasis. When enabled, only `*text*` works for italic emphasis.
- **`superscript`**: When `true`, parses `^text^` as superscript. Visual appearance can be tuned with the `superscript` style prop — see [Superscript-specific](./STYLES.md#superscript-specific).
- **`subscript`**: When `true`, parses `~text~` as subscript. When disabled, single and double tildes remain strikethrough markers. Visual appearance can be tuned with the `subscript` style prop — see [Subscript-specific](./STYLES.md#subscript-specific).
- **`highlight`**: When `true`, parses `==text==` as highlighted spans. When disabled, double equals signs are treated as plain text. Visual appearance can be tuned with the `highlight` style prop — see [Highlight-specific](./STYLES.md#highlight-specific).
- **`latexMath`**: When `true`, parses `$...$` and `$$...$$` as LaTeX math spans.
- **`hardSoftBreaks`**: When `true`, treats single newlines (soft breaks) as hard breaks, rendering them as visible line breaks instead of collapsing them to spaces. Useful when displaying content authored in `EnrichedMarkdownTextInput`, where pressing Enter produces a single newline. See [Line Breaks](./ELEMENTS_STRUCTURE.md#line-breaks) for details.
- **`preserveBlankLines`**: When `true`, preserves runs of consecutive blank lines from the source instead of collapsing them into a single paragraph break (per CommonMark). Each blank line renders as one empty line, so the output keeps the exact line count that was typed. See [Blank Lines](./ELEMENTS_STRUCTURE.md#blank-lines) for details.

**Example:**

```tsx
// Default: _text_ is treated as italic
<EnrichedMarkdownText
  markdown="This is _italic_ text"
/>

// With underline enabled: _text_ is underlined, *text* is italic
<EnrichedMarkdownText
  markdown="This is _underlined_ and *italic* text"
  md4cFlags={{ underline: true }}
/>

// Preserve single newlines as visible line breaks
<EnrichedMarkdownText
  markdown={markdownFromInput}
  md4cFlags={{ hardSoftBreaks: true }}
/>
```

### `allowFontScaling`

Whether fonts should scale to respect Text Size accessibility settings.

| Type      | Default Value | Platform |
| --------- | ------------- | -------- |
| `boolean` | `true`         | Both     |

### `maxFontSizeMultiplier`

Maximum font scale multiplier when `allowFontScaling` is enabled.

| Type     | Default Value | Platform |
| -------- | ------------- | -------- |
| `number` | `undefined`   | Both     |

### `allowTrailingMargin`

Whether to preserve the bottom margin of the last block element.

| Type      | Default Value | Platform |
| --------- | ------------- | -------- |
| `boolean` | `false`        | Both     |

### `textBreakStrategy`

Controls how Android breaks lines within paragraphs. Mirrors the prop of the same name on React Native's core `Text`. The same value is used for both the measurement pass (`StaticLayout.Builder`) and the rendered `TextView`, so measured and rendered line counts stay in sync. Requires API 23+; ignored on older Android versions.

| Type                                          | Default Value   | Platform |
| --------------------------------------------- | --------------- | -------- |
| `'simple' \| 'highQuality' \| 'balanced'`     | `'highQuality'` | Android  |

- **`'simple'`**: greedy, no hyphenation; cheapest.
- **`'highQuality'`** (default): full paragraph optimization with hyphenation.
- **`'balanced'`**: balances line lengths across the paragraph; no hyphenation.

### `lineBreakStrategyIOS`

Controls iOS line-breaking refinements. Mirrors the prop of the same name on React Native's core `Text`. Maps to `NSParagraphStyle.lineBreakStrategy`. Requires iOS 14+; on earlier versions the prop is ignored.

| Type                                                       | Default Value | Platform |
| ---------------------------------------------------------- | ------------- | -------- |
| `'none' \| 'standard' \| 'hangul-word' \| 'push-out'`      | `'none'`      | iOS      |

- **`'none'`** (default): no additional line-break strategy.
- **`'standard'`**: enables the system's standard line-break refinements.
- **`'hangul-word'`**: prefers breaking at Korean word boundaries.
- **`'push-out'`**: avoids orphaned short trailing lines by pushing words to the next line.

### `writingDirection`

Paragraph writing direction. iOS only — Android already resolves direction per paragraph via the platform Bidi heuristic and is unaffected by this prop.

| Type                                            | Default Value    | Platform |
| ----------------------------------------------- | ---------------- | -------- |
| `'auto' \| 'ltr' \| 'rtl' \| 'first-strong'`    | `'first-strong'` | iOS      |

- **`'first-strong'`** (default): library extension. Each paragraph resolves its base direction from its first strong directional character — mixed Arabic/Hebrew/English documents render correctly out of the box. Paragraphs with no strong character (numbers, punctuation, block spacers) fall back to the view's Yoga-resolved layout direction, which inherits from any ancestor `<View style={{ direction: 'rtl' }}>` (defaults to `I18nManager.isRTL`). Mirrors Android's `TEXT_DIRECTION_FIRST_STRONG`.
- **`'auto'`**: React Native parity (matches `<Text writingDirection="auto">`). TextKit follows the app's `userInterfaceLayoutDirection`; mixed-direction paragraphs do not auto-resolve.
- **`'ltr'` / `'rtl'`**: forces the base direction on every paragraph in the document.

Code blocks are always rendered left-to-right regardless of this prop. Per-paragraph direction also drives list markers, blockquote borders, task-list tap targets, and the `dir` attribute emitted when copying as HTML. See [RTL Support](RTL.md) for the full behavior matrix and the copy-as-HTML caveat for mixed-direction documents.

**Example:**

```tsx
// Mixed-direction document — each paragraph picks its own side.
<EnrichedMarkdownText
  markdown={
    'هذه فقرة عربية\n\n' +
    'This English paragraph stays LTR.\n\n' +
    '123 456 789.' // neutral — follows the view's layout direction
  }
/>

// Force RTL on every paragraph regardless of content.
<EnrichedMarkdownText writingDirection="rtl" markdown={content} />
```

### `flavor`

Markdown flavor. Set to `'github'` to enable GitHub Flavored Markdown features: tables, block-style code blocks, and block-style blockquotes.

| Type                              | Default Value   | Platform |
| --------------------------------- | --------------- | -------- |
| `'commonmark' \| 'github'`        | `'commonmark'`  | Both     |

> **Note:** 
> - **`'commonmark'`**: All Markdown content is rendered as a single TextView. Selecting text will select all content in the view.
> - **`'github'`**: The Markdown AST is split into segments. Consecutive text blocks (paragraphs, headings, lists, etc.) are grouped into separate TextView segments, while tables, fenced code blocks, math blocks, and blockquotes are rendered as separate block views. This allows for granular text selection within each segment and enables interactive block features (horizontal table scrolling, context menus, the code block header). Text selection cannot span across segments.
>
> With `'github'`, a fenced code block renders as a dedicated component: a header bar with the language display name (` ```python ` shows "Python") and a copy-code button, a divider, and the code below. Long lines do not wrap — the code pane scrolls horizontally while the header stays fixed. Long-pressing the block opens the Copy / Copy as Markdown menu. With `'commonmark'`, code blocks stay inside the single TextView, styled via spans, and long lines wrap.
>
> With `'github'`, a blockquote also renders as a dedicated component — a recursive container that draws its own box (padding, `backgroundColor`, and accent border with `borderRadius`) and splits its own content into segments. A code block, table, or math block quoted inside therefore becomes a real nested block component, and each nesting level is its own box. With `'commonmark'`, blockquotes stay inside the single TextView, styled via spans.

### `streamingAnimation`

When `true`, newly appended content fades in during streaming updates. Only the tail (new characters beyond the previous content) is animated. Recommended for LLM streaming use cases.

| Type      | Default Value | Platform |
| --------- | ------------- | -------- |
| `boolean` | `false`       | Both     |

### `streamingConfig`

Configuration for streaming behavior. Controls how incomplete tables and fenced code blocks are handled during streaming with `flavor="github"`.

| Type                                        | Default Value                                          | Platform |
| ------------------------------------------- | ------------------------------------------------------ | -------- |
| `{ tableMode?: string, codeBlockMode?: string }` | `{ tableMode: 'progressive', codeBlockMode: 'progressive' }` | Both     |

#### `tableMode`

Controls how incomplete (still-streaming) tables are rendered:

- **`'progressive'`** (default): The table is rendered row-by-row as content arrives. Requires at least a header row and separator line before anything is shown. Incomplete trailing rows (missing closing `|` or fewer columns than the header) are trimmed. New rows fade in with animation when `streamingAnimation` is also enabled.
- **`'hidden'`**: The entire table is hidden until it is complete (followed by a blank line). This prevents visual jank from partially formed tables.

```tsx
<EnrichedMarkdownText
  markdown={streamingMarkdown}
  flavor="github"
  streamingAnimation
  streamingConfig={{ tableMode: 'hidden' }}
/>
```

#### `codeBlockMode`

Controls how a fenced code block whose closing fence has not arrived yet is rendered:

- **`'progressive'`** (default): The code streams in line-by-line with its header (language label + copy button) visible but non-interactive — copying is disabled until the block completes. Syntax highlighting is deferred until the closing fence arrives, so it applies once instead of flickering on every token.
- **`'hidden'`**: The entire code block is hidden until its closing fence arrives, then it appears complete (the same all-or-nothing behavior block math uses).

Both modes only take effect when `streamingAnimation` is `true`.

### `spoilerOverlay`

Controls how spoiler text (`||hidden text||`) is displayed before being revealed.

| Type                          | Default Value | Platform |
| ----------------------------- | ------------- | -------- |
| `'particles' \| 'solid'`     | `'particles'` | Both     |

- **`'particles'`**: Animated particle overlay (CAEmitterLayer on iOS, Choreographer-driven Canvas particles on Android).
- **`'solid'`**: Opaque rectangle covering the text (Discord-style).

Both modes support tap-to-reveal.

### `imageRequestHeaders`

HTTP headers attached to remote image requests, e.g. a `Referer` required by CDN hotlink protection or an `Authorization` token.

| Type                     | Default Value | Platform |
| ------------------------ | ------------- | -------- |
| `Record<string, string>` | -             | Both     |

Headers participate in image cache identity, so the same URL requested with different headers is fetched and cached separately — see [Image Caching](./IMAGE_CACHING.md).

> **Web**: Not supported — browsers don't allow custom headers on `<img>` requests.

**Example:**

```tsx
<EnrichedMarkdownText
  markdown={markdown}
  imageRequestHeaders={{
    Referer: 'https://example.com',
  }}
/>
```

### `contextMenuItems`

Custom items to add to the text selection context menu. Items appear before the system actions (Copy, etc.). Items with `visible: false` are hidden from the menu.

> **iOS**: Requires iOS 16+. On earlier versions the prop is ignored.

| Type                 | Default Value | Platform |
| -------------------- | ------------- | -------- |
| `ContextMenuItem[]`  | -             | Both     |

**`ContextMenuItem` shape:**

```ts
interface ContextMenuItem {
  /** Label shown in the context menu. */
  text: string;
  /**
   * SF Symbol name for the icon shown next to the item label.
   * Supported on iOS and macOS. Ignored on Android.
   * Example: 'sparkles', 'translate', 'doc.text'
   */
  icon?: string;
  /** Called when the item is tapped. */
  onPress: (event: {
    /** The selected text at the time of the press. */
    text: string;
    /** Absolute character range of the selection within the full content. */
    selection: { start: number; end: number };
  }) => void;
  /** When false, the item is not shown in the menu. Defaults to true. */
  visible?: boolean;
}
```

**Example:**

```tsx
<EnrichedMarkdownText
  markdown={content}
  contextMenuItems={[
    {
      text: 'Summarize with AI',
      onPress: ({ text }) => {
        console.log('Selected:', text);
      },
    },
    {
      text: 'Translate',
      onPress: ({ text }) => {
        translate(text);
      },
    },
  ]}
/>
```

### `selectionMenuConfig`

Controls built-in actions added to the native text selection menu. Custom app-provided actions are controlled separately with `contextMenuItems`.

| Type                 | Default Value                                  | Platform |
| -------------------- | ---------------------------------------------- | -------- |
| `SelectionMenuConfig` | `{}` (see shape below for per-field defaults) | iOS, Android, macOS |

Each item takes an object: `{ enabled }` toggles visibility (the system `copy` item can't be hidden — only relabeled) and `label` overrides the English default. The labels apply to the main text selection menu as well as the table and math block copy menus.

> **Deprecation:** the previous boolean shape (`copyAsMarkdown: false`) is still accepted at runtime for backward compatibility but logs a one-time warning. It will be removed in 0.8 — migrate to `{ enabled: false }`.

**`SelectionMenuConfig` shape:**

```ts
interface SelectionMenuConfig {
  /** System "Copy" item — can't be hidden, only relabeled. @default { label: "Copy" } */
  copy?: { label?: string };
  /** "Copy as Markdown" action. @default { enabled: true, label: "Copy as Markdown" } */
  copyAsMarkdown?: { enabled?: boolean; label?: string };
  /** "Copy Image URL" action, shown when the selection contains images. */
  copyImageUrl?: {
    enabled?: boolean;
    /** Label for a single image. @default "Copy Image URL" */
    label?: string;
    /** Forms for multiple images, chosen with Intl.PluralRules. @default { other: "Copy {count} Image URLs" } */
    pluralLabels?: SelectionMenuPluralLabels;
  };
}

interface SelectionMenuPluralLabels {
  /** CLDR plural categories. `{count}` is replaced by the image count. Missing
   *  categories fall back to `other`, so only `other` is required. */
  other: string;
  zero?: string;
  one?: string;
  two?: string;
  few?: string;
  many?: string;
}
```

**Example:**

```tsx
<EnrichedMarkdownText
  markdown={content}
  selectionMenuConfig={{
    // Hide an action:
    copyAsMarkdown: { enabled: false },
    // Localize the labels:
    copy: { label: t('copy') },
    copyImageUrl: {
      label: t('copyImageUrl'),
      pluralLabels: { other: t('copyImageUrls') }, // "{count}" → image count
    },
  }}
/>
```

See [COPY_OPTIONS.md](./COPY_OPTIONS.md#localizing-menu-labels) for details.

> **Note:** When using `flavor="github"`, `selection.start` and `selection.end` are relative to the text segment the selection is in, not the full markdown string. With `flavor="commonmark"` (default) they are always absolute within the full rendered text.

---

### `accessibilityLabels`

Translates every string spoken by VoiceOver (iOS) and TalkBack (Android) when navigating the rendered markdown. All fields are optional; omitted fields fall back to the English defaults defined in `accessibilityLabelDefaults.ts`. See the [Accessibility guide](ACCESSIBILITY.md#translating-announcements--accessibilitylabels) for the full defaults table and placeholder syntax.

| Type                  | Default Value                | Platform        |
| --------------------- | ---------------------------- | --------------- |
| `AccessibilityLabels` | English strings (see guide)  | iOS, Android    |

**`AccessibilityLabels` shape:**

```ts
interface AccessibilityLabels {
  list?: {
    bulletPoint?: string;          // "Bullet point"
    nestedBulletPoint?: string;    // "Nested bullet point"
    orderedItem?: string;          // "List item {n}"
    nestedOrderedItem?: string;    // "Nested list item {n}"
  };
  blockquote?: {
    quote?: string;                // "Blockquote"
    nestedQuote?: string;          // "Nested blockquote"
  };
  table?: {
    row?: string;                  // "Row {n}: {content}"
  };
  math?: {
    equation?: string;             // "Math: {latex}"
  };
  rotor?: {                        // iOS only
    headings?: string;             // "Headings"
    links?: string;                // "Links"
    images?: string;               // "Images"
  };
}
```

Placeholders (`{n}`, `{content}`, `{latex}`) are substituted on the native side at speak time and must be preserved in translations.

**Example:**

```tsx
<EnrichedMarkdownText
  markdown={content}
  accessibilityLabels={{
    list: { bulletPoint: 'Punkt', orderedItem: 'Element {n}' },
    blockquote: { quote: 'Zitat' },
    math: { equation: 'Formel: {latex}' },
  }}
/>
```

---

## EnrichedMarkdownTextInput

### Props

### `defaultValue`

Initial Markdown content for the input. The Markdown is parsed and formatting is applied on mount.

| Type     | Default Value | Platform |
| -------- | ------------- | -------- |
| `string` | -             | Both     |

### `placeholder`

Placeholder text displayed when the input is empty.

| Type     | Default Value | Platform |
| -------- | ------------- | -------- |
| `string` | -             | Both     |

### `placeholderTextColor`

Color of the placeholder text.

| Type         | Default Value | Platform |
| ------------ | ------------- | -------- |
| `ColorValue` | -             | Both     |

### `editable`

Whether the input is editable.

| Type      | Default Value | Platform |
| --------- | ------------- | -------- |
| `boolean` | `true`        | Both     |

### `autoFocus`

Whether the input should be focused on mount.

| Type      | Default Value | Platform |
| --------- | ------------- | -------- |
| `boolean` | `false`       | Both     |

### `scrollEnabled`

Whether the input is scrollable when content exceeds the visible area.

| Type      | Default Value | Platform |
| --------- | ------------- | -------- |
| `boolean` | `true`        | Both     |

### `autoCapitalize`

Auto-capitalization behavior.

| Type     | Default Value  | Platform |
| -------- | -------------- | -------- |
| `string` | `'sentences'`  | Both     |

### `multiline`

Whether the input supports multiple lines.

| Type      | Default Value | Platform |
| --------- | ------------- | -------- |
| `boolean` | `true`        | Both     |

### `cursorColor`

Color of the text cursor.

| Type         | Default Value | Platform |
| ------------ | ------------- | -------- |
| `ColorValue` | -             | Both     |

### `selectionColor`

Color of the text selection highlight.

| Type         | Default Value | Platform |
| ------------ | ------------- | -------- |
| `ColorValue` | -             | Both     |

### `markdownStyle`

Style configuration for formatted text in the input.

| Type                 | Default Value | Platform |
| -------------------- | ------------- | -------- |
| `MarkdownTextInputStyle` | `{}`          | Both     |

**Properties:**

- `strong.color` — text color for bold text (defaults to the input's text color).
- `em.color` — text color for italic text (defaults to the input's text color).
- `link.color` — text color for links (defaults to `#2563EB`).
- `link.underline` — whether links are underlined (defaults to `true`).
- `link.backgroundColor` — background color for links (defaults to `transparent`).
- `linkVariants` — per-URL-pattern style overrides. Each key is a regex tested against the link URL. See [Mentions — Link Variants](MENTIONS.md#link-variants-mention-styling).
- `spoiler.color` — text color for spoiler text.
- `spoiler.backgroundColor` — background color for spoiler text.
- `h1`–`h6` — per-level heading styling, each accepting `fontSize`, `fontWeight`, and `color`. Defaults match the read-only renderer (sizes `30/24/20/18/16/14`, bold).
- `list.itemSpacing` — vertical spacing (points) added above each list item (bullet and numbered alike) so items read as separate rows; defaults to `0`. iOS applies it via `paragraphSpacingBefore`; Android via a `LineHeightSpan`.

### `mentionIndicators`

List of trigger strings that start a mention flow (e.g. `['@', '#']`). See [Mentions](MENTIONS.md).

| Type       | Default Value | Platform |
| ---------- | ------------- | -------- |
| `string[]` | `[]`          | Both     |

### `style`

Style for the input view. Accepts `ViewStyle` and `TextStyle` properties (e.g., `fontSize`, `color`, `padding`).

| Type                    | Default Value | Platform |
| ----------------------- | ------------- | -------- |
| `ViewStyle \| TextStyle` | -             | Both     |

### Events

### `onChangeText`

Fires when the plain text content changes. Returns the text without Markdown syntax.

| Type                            | Default Value | Platform |
| ------------------------------- | ------------- | -------- |
| `(text: string) => void`       | -             | Both     |

### `onChangeMarkdown`

Fires when the Markdown representation changes. Returns the full Markdown string. Only active when the callback is provided — omitting it skips the serialization for better performance.

| Type                                | Default Value | Platform |
| ----------------------------------- | ------------- | -------- |
| `(markdown: string) => void`       | -             | Both     |

### `onChangeSelection`

Fires when the text selection changes.

| Type                                                  | Default Value | Platform |
| ----------------------------------------------------- | ------------- | -------- |
| `(selection: { start: number; end: number }) => void` | -             | Both     |

### `onChangeState`

Fires when the active style state changes. The payload provides a nested object for each style with an `isActive` property; `heading` additionally carries the cursor paragraph's `level` (`0` when it is not a heading) and `unorderedList` / `orderedList` their 0-based nesting `depth`.

| Type                              | Default Value | Platform |
| --------------------------------- | ------------- | -------- |
| `(state: StyleState) => void`    | -             | Both     |

**`StyleState` shape:**

```ts
interface StyleState {
  bold: { isActive: boolean };
  italic: { isActive: boolean };
  underline: { isActive: boolean };
  strikethrough: { isActive: boolean };
  spoiler: { isActive: boolean };
  link: { isActive: boolean };
  // Heading level of the cursor's paragraph: 0 = none, 1-6 = H1-H6.
  heading: { isActive: boolean; level: number };
  // `depth` is the 0-based nesting level while `isActive` is true, and is
  // always `0` when `isActive` is false (i.e. the cursor is not in a list).
  // This differs from `heading.level`, where `0` is itself a meaningful value
  // (no heading); read `depth` only when `isActive` is true.
  unorderedList: { isActive: boolean; depth: number };
  orderedList: { isActive: boolean; depth: number };
}
```

### `onKeyPress`

Fires on every keystroke, before the change is applied to the input content — mirroring React Native TextInput's `onKeyPress`. `nativeEvent.key` is the pressed character, or a named key: `Backspace`, `Enter`, `Tab` (iOS additionally reports `Escape`). On Android the key reported for soft keyboard input may lag actual typing when autocomplete suggestions are involved. Paste operations do not fire the event.

| Type                                                          | Default Value | Platform |
| ------------------------------------------------------------- | ------------- | -------- |
| `(e: NativeSyntheticEvent<{ key: string }>) => void`          | -             | Both     |

**Example:**

```tsx
<EnrichedMarkdownTextInput
  onKeyPress={({ nativeEvent: { key } }) => {
    console.log('Pressed key:', key);
  }}
/>
```

### `onCaretRectChange`

Fires when the caret's pixel position changes (typing, selection change, content reflow). The rect is relative to the input's top-left corner, in density-independent pixels. The native side diffs the rect before emitting, so redundant events are suppressed.

| Type                              | Default Value | Platform |
| --------------------------------- | ------------- | -------- |
| `(rect: CaretRect) => void`      | -             | Both     |

**`CaretRect` shape:**

```ts
interface CaretRect {
  x: number;
  y: number;
  width: number;
  height: number;
}
```

All values are in density-independent pixels, relative to the input's top-left corner.

**Example:**

```tsx
<EnrichedMarkdownTextInput
  scrollEnabled={false}
  onCaretRectChange={(rect) => {
    console.log('Caret at:', rect.x, rect.y);
  }}
/>
```

### `onFocus`

Fires when the input gains focus.

| Type           | Default Value | Platform |
| -------------- | ------------- | -------- |
| `() => void`   | -             | Both     |

### `onBlur`

Fires when the input loses focus.

| Type           | Default Value | Platform |
| -------------- | ------------- | -------- |
| `() => void`   | -             | Both     |

The input participates in React Native's text-input focus tracking (`TextInput.State`), so blur also happens through the platform's standard keyboard-dismiss paths: taps outside the input inside a `ScrollView` (per its `keyboardShouldPersistTaps` setting) and `Keyboard.dismiss()`. See [Keyboard Dismissal](INPUT.md#keyboard-dismissal).

### `onStartMention`

Fires when a new mention flow starts. See [Mentions](MENTIONS.md#events).

| Type | Default Value | Platform |
| ---- | ------------- | -------- |
| `(event: { indicator: string }) => void` | - | Both |

### `onChangeMention`

Fires on every keystroke while a mention flow is active.

| Type | Default Value | Platform |
| ---- | ------------- | -------- |
| `(event: { indicator: string; text: string }) => void` | - | Both |

### `onEndMention`

Fires when the active mention flow ends.

| Type | Default Value | Platform |
| ---- | ------------- | -------- |
| `(event: { indicator: string }) => void` | - | Both |

### `writingDirection`

Paragraph writing direction in the input. iOS only — Android's `EditText` already resolves direction per paragraph via `TEXT_DIRECTION_FIRST_STRONG` and is unaffected by this prop.

| Type                                            | Default Value    | Platform |
| ----------------------------------------------- | ---------------- | -------- |
| `'auto' \| 'ltr' \| 'rtl' \| 'first-strong'`    | `'first-strong'` | iOS      |

- **`'first-strong'`** (default): each paragraph resolves its base direction from its first strong directional character. Neutral-only paragraphs fall back to the view's Yoga-resolved layout direction. Mirrors Android's platform behavior.
- **`'auto'`**: React Native parity. TextKit follows the app's `userInterfaceLayoutDirection`; mixed-direction paragraphs do not auto-resolve.
- **`'ltr'` / `'rtl'`**: forces the base direction on every paragraph in the input.

See [INPUT — RTL Support](INPUT.md#rtl-support) for caveats (placeholder direction, mixed-paragraph typing).

### `contextMenuItems`

Custom items to add to the text selection context menu. Items appear before the system actions (Copy, Cut, etc.). Items with `visible: false` are hidden from the menu.

> **iOS**: Requires iOS 16+. On earlier versions the prop is ignored.

| Type                 | Default Value | Platform |
| -------------------- | ------------- | -------- |
| `ContextMenuItem[]`  | -             | Both     |

**`ContextMenuItem` shape:**

```ts
interface ContextMenuItem {
  /** Label shown in the context menu. */
  text: string;
  /**
   * SF Symbol name for the icon shown next to the item label.
   * Supported on iOS and macOS. Ignored on Android.
   * Example: 'sparkles', 'translate', 'doc.text'
   */
  icon?: string;
  /** Called when the item is tapped. */
  onPress: (event: {
    /** The selected text at the time of the press. */
    text: string;
    /** Absolute character range of the selection within the full content. */
    selection: { start: number; end: number };
    /** Active formatting styles at the time of the press. */
    styleState: {
      bold: { isActive: boolean };
      italic: { isActive: boolean };
      underline: { isActive: boolean };
      strikethrough: { isActive: boolean };
      spoiler: { isActive: boolean };
      link: { isActive: boolean };
    };
  }) => void;
  /** When false, the item is not shown in the menu. Defaults to true. */
  visible?: boolean;
}
```

**Example:**

```tsx
<EnrichedMarkdownTextInput
  contextMenuItems={[
    {
      text: 'Summarize with AI',
      onPress: ({ text, styleState }) => {
        console.log('Selected:', text, 'Bold:', styleState.bold.isActive);
      },
    },
  ]}
/>
```

### `selectionMenuConfig`

Controls built-in items in the text selection context menu — the **Format** submenu (Bold, Italic, …) and the **Copy as Markdown** action. Each item takes an object: `{ enabled }` toggles visibility and `label` overrides the English default; `format.label` controls the submenu title itself. Custom app-provided actions are controlled separately with `contextMenuItems`.

| Type                       | Default Value                          | Platform            |
| -------------------------- | -------------------------------------- | ------------------- |
| `InputSelectionMenuConfig` | `{}` (see shape below for per-field defaults) | iOS, Android, macOS |

**`InputSelectionMenuConfig` shape:**

```ts
interface InputSelectionMenuConfig {
  /** The "Format" submenu. @default { enabled: true, label: "Format" } */
  format?: { enabled?: boolean; label?: string };
  /** "Copy as Markdown" action. @default { enabled: true, label: "Copy as Markdown" } */
  copyAsMarkdown?: { enabled?: boolean; label?: string };
}
```

**Example:**

```tsx
// Hide both the Format submenu and the Copy as Markdown action
<EnrichedMarkdownTextInput
  selectionMenuConfig={{
    format: { enabled: false },
    copyAsMarkdown: { enabled: false },
  }}
/>

// Localize the visible labels
<EnrichedMarkdownTextInput
  selectionMenuConfig={{
    format: { label: t('format') },
    copyAsMarkdown: { label: t('copyAsMarkdown') },
  }}
/>
```

See [COPY_OPTIONS.md](./COPY_OPTIONS.md#localizing-menu-labels) for details on the localization pattern.

### `formatMenuConfig`

Controls which items appear inside the Format submenu and the label for each. Only effective when `selectionMenuConfig.format` is enabled (the default). Same `{ enabled?, label? }` shape as `selectionMenuConfig` above.

| Type               | Default Value                                  | Platform            |
| ------------------ | ---------------------------------------------- | ------------------- |
| `FormatMenuConfig` | `{}` (see shape below for per-field defaults)  | iOS, Android, macOS |

**`FormatMenuConfig` shape:**

```ts
interface FormatMenuConfig {
  /** @default { enabled: true, label: "Bold" } */
  bold?: { enabled?: boolean; label?: string };
  /** @default { enabled: true, label: "Italic" } */
  italic?: { enabled?: boolean; label?: string };
  /** @default { enabled: true, label: "Underline" } */
  underline?: { enabled?: boolean; label?: string };
  /** @default { enabled: true, label: "Strikethrough" } */
  strikethrough?: { enabled?: boolean; label?: string };
  /** @default { enabled: true, label: "Spoiler" } */
  spoiler?: { enabled?: boolean; label?: string };
  /** @default { enabled: true, label: "Link" } */
  link?: { enabled?: boolean; label?: string };
}
```

**Example:**

```tsx
// Hide Spoiler and Link from the Format submenu
<EnrichedMarkdownTextInput
  formatMenuConfig={{
    spoiler: { enabled: false },
    link: { enabled: false },
  }}
/>

// Localize every item
<EnrichedMarkdownTextInput
  formatMenuConfig={{
    bold: { label: t('bold') },
    italic: { label: t('italic') },
    underline: { label: t('underline') },
    strikethrough: { label: t('strikethrough') },
    spoiler: { label: t('spoiler') },
    link: { label: t('link') },
  }}
/>
```

> System **Cut / Copy / Paste / Select All** items come from the platform (UIKit `UITextView`, Android `ActionMode`) and are already localized by the device language — they are not exposed through `selectionMenuConfig`.

### Ref Methods

All methods are called imperatively on the ref (`ref.current?.methodName()`).

### `focus()`

Focuses the input.

### `blur()`

Blurs the input.

### `setValue(markdown: string)`

Sets the input content from a Markdown string. Parses the Markdown and applies formatting.

### `getMarkdown(): Promise<string>`

Returns a Promise that resolves with the current Markdown content. The async nature is due to the native bridge — the request is sent to the native side and the result is returned via an event.

### `getCaretRect(): Promise<CaretRect>`

Returns a Promise that resolves with the current caret's pixel position relative to the input. Useful for one-off queries; for continuous tracking, prefer `onCaretRectChange`.

### `setSelection(start: number, end: number)`

Sets the text selection range.

### `toggleBold()`

Toggles bold on the current selection. When no text is selected, the style is queued and applied to the next characters typed.

### `toggleItalic()`

Toggles italic on the current selection or cursor.

### `toggleUnderline()`

Toggles underline on the current selection or cursor.

### `toggleStrikethrough()`

Toggles strikethrough on the current selection or cursor.

### `toggleSpoiler()`

Toggles spoiler on the current selection or cursor.

### `toggleHeading(level: number)`

Toggles a heading of the given level (`1`–`6`) on the cursor's paragraph. Calling it with the level already applied turns the paragraph back into regular text. Unlike the inline `toggle*` methods, this operates on the whole paragraph, not a character range.

### `toggleUnorderedList()`

Turns the cursor's paragraph(s) into bullet list items, or back into regular paragraphs if they already are. Operates on the whole paragraph. List items are single-line — each item is exactly one paragraph, and Markdown imported with multi-paragraph (loose) items keeps only each item's first line as a list item.

### `toggleOrderedList()`

Turns the cursor's paragraph(s) into numbered list items, or back into regular paragraphs if they already are. Numbering derives from an item's position among its adjacent same-depth siblings. Toggling one list type on a line carrying the other replaces it, keeping the item's nesting depth.

### `indentList()`

Nests the current list item one level deeper (up to a maximum depth). Called on a non-list paragraph, it starts a bullet list at depth 0. Equivalent to pressing **Tab** with a hardware keyboard.

### `outdentList()`

Lifts the current list item out one nesting level. Outdenting a depth-0 item removes the bullet, turning it back into a regular paragraph. Equivalent to **Shift+Tab**.

### `setLink(url: string)`

Applies a link URL to the currently selected text.

### `insertLink(text: string, url: string)`

Inserts a link with the given text and URL at the current cursor position. Useful when there is no text selection.

### `removeLink()`

Removes the link from the current selection.

### `insertText(text: string)`

Parses the given string as Markdown and inserts it literally at the current cursor position, replacing the selection if there is one. Leading and trailing newlines are preserved, so wrap block content (lists, headings) in newlines to keep it on its own lines when inserting mid-paragraph — `insertText('\n- item\n')` in the middle of `test` yields `te`, a `- item` bullet, and `st` on separate lines. Calling it with an empty string is a no-op.

### `copyToClipboard()`

Copies the input's full content to the system clipboard, matching the result of selecting all text and pressing the context menu's copy action. The selection is left unchanged, and calling it on an empty input is a no-op.

On iOS and macOS the clipboard receives both plain text and a private Markdown pasteboard type, so pasting back into an `EnrichedMarkdownTextInput` restores the formatting; external apps receive plain text only. On Android the clipboard receives plain text only — inline styles are not preserved for any paste target.

### `startMention(indicator: string)`

Programmatically triggers a mention flow by inserting the indicator character at the current cursor position. The indicator must be listed in the `mentionIndicators` prop. Useful for toolbar buttons.

### `insertMention(displayText: string, url: string)`

Replaces the active mention token with a formatted link. Only works when a mention flow is active. The mention is serialized as `[displayText](url)` in Markdown output.

---

## Mentions

For full documentation on the mention system — setup, events, styling, and best practices — see [Mentions](MENTIONS.md).
