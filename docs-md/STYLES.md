# Style Properties Reference

This document provides a comprehensive reference for all style properties available in `react-native-enriched-markdown`.

## Platform Defaults

The library provides sensible defaults optimized for each platform:

| Property | iOS | Android |
|----------|-----|---------|
| System Font | SF Pro | Roboto |
| Monospace Font | Menlo | monospace |
| Line Height | Tighter (0.75x multiplier) | Standard |

## Style Inheritance

`react-native-enriched-markdown` uses a base block style architecture where all block elements (paragraphs, headings, lists, blockquotes, code blocks) share a common set of typography properties. This base block style includes:

- `fontSize` - Font size in points
- `fontFamily` - Font family name
- `fontWeight` - Font weight
- `color` - Text color
- `marginTop` - Top margin
- `marginBottom` - Bottom margin
- `lineHeight` - Line height

Each block type extends this base style with its own specific properties (e.g., `textAlign` for paragraphs and headings, `borderColor` for blockquotes, `bulletColor` for lists).

### Inline Style Inheritance

Inline styles (strong, emphasis, links, inline code, etc.) automatically inherit the base typography properties from their containing block. This means inline elements use the block's `fontSize`, `fontFamily`, `fontWeight`, and `color` as their foundation, then apply their own additional styling on top.

**Example:**

```
Heading (h2: fontSize 24, color blue)
└── Strong text inherits → fontSize 24, color blue + bold weight
└── Link inherits → fontSize 24 + link color + underline

List item (list: fontSize 16, color gray)
└── Emphasis inherits → fontSize 16, color gray + italic style
└── Inline code inherits → fontSize 16 + code background
```

This inheritance model ensures consistent typography throughout your Markdown content while allowing inline elements to add their own visual emphasis.

### Custom Font Family for Inline Styles

Strong, emphasis, and inline code support an optional `fontFamily` property that gives you full control over the font face used for that element.

**Default behavior (no `fontFamily` set):**
- **Strong** — adds the bold trait to the current block font
- **Emphasis** — adds the italic trait to the current block font
- **Inline code** — uses the platform's system monospace font (SF Mono on iOS, monospace on Android)

**With `fontFamily` set:**

By default, bold/italic traits are still applied on top of the custom font family. Use `fontWeight: 'normal'` or `fontStyle: 'normal'` to disable this and use the font face exactly as-is:

```tsx
markdownStyle={{
  strong: {
    // Bold trait is applied on top of Montserrat-Bold (default: fontWeight 'bold')
    fontFamily: 'Montserrat-Bold',
  },
  strong: {
    // Uses Montserrat-SemiBold as-is, no bold trait added
    fontFamily: 'Montserrat-SemiBold',
    fontWeight: 'normal',
  },
  em: {
    // Italic trait is applied on top of Montserrat-Italic (default: fontStyle 'italic')
    fontFamily: 'Montserrat-Italic',
  },
  em: {
    // Uses Montserrat-Regular as-is, no italic trait added
    fontFamily: 'Montserrat-Regular',
    fontStyle: 'normal',
  },
  code: {
    // Uses CutiveMono-Regular directly, no system monospace applied
    fontFamily: 'CutiveMono-Regular',
  },
}}
```

## Customizing Styles

The library provides sensible default styles for all Markdown elements out of the box. You can override any of these defaults using the `markdownStyle` prop — only specify the properties you want to change:

```tsx
<EnrichedMarkdownText
  markdown={content}
  markdownStyle={{
    paragraph: {
      fontSize: 16,
      color: '#333',
      lineHeight: 24,
    },
    h1: {
      fontSize: 32,
      fontWeight: 'bold',
      color: '#000',
      marginBottom: 16,
      textAlign: 'center',
    },
    h2: {
      fontSize: 24,
      fontWeight: '600',
      marginBottom: 12,
      textAlign: 'left',
    },
    strong: {
      fontFamily: 'Montserrat-Bold',
      color: '#000',
    },
    em: {
      fontFamily: 'Montserrat-Italic',
      color: '#666',
    },
    strikethrough: {
      color: '#999',
    },
    underline: {
      color: '#333',
    },
    link: {
      fontFamily: 'System-Bold',
      color: '#007AFF',
      underline: true,
    },
    code: {
      fontFamily: 'CutiveMono-Regular',
      fontSize: 16,
      color: '#E91E63',
      backgroundColor: '#F5F5F5',
      borderColor: '#E0E0E0',
    },
    codeBlock: {
      fontSize: 14,
      fontFamily: 'monospace',
      backgroundColor: '#1E1E1E',
      color: '#D4D4D4',
      padding: 16,
      borderRadius: 8,
      marginBottom: 16,
    },
    blockquote: {
      borderColor: '#007AFF',
      borderWidth: 3,
      backgroundColor: '#F0F8FF',
      borderRadius: 8,
      padding: 12,
      marginBottom: 12,
    },
    list: {
      fontSize: 16,
      bulletColor: '#007AFF',
      bulletSize: 6,
      markerColor: '#007AFF',
      gapWidth: 8,
      marginLeft: 20,
    },
    image: {
      borderRadius: 8,
      marginBottom: 12,
    },
    inlineImage: {
      size: 20,
    },
    taskList: {
      checkedColor: '#2196F3',
      borderColor: '#9E9E9E',
      checkmarkColor: '#FFFFFF',
      checkboxSize: 16,
    },
    math: {
      fontSize: 20,
      color: '#1F2937',
      backgroundColor: '#F3F4F6',
      padding: 12,
      marginBottom: 16,
      textAlign: 'center',
    },
    inlineMath: {
      color: '#1F2937',
    },
    spoiler: {
      color: '#6B7280',
      particles: { density: 10, speed: 25 },
      solid: { borderRadius: 6 },
    },
    superscript: {
      fontScale: 0.75,
      baselineOffsetScale: 0.35,
    },
    subscript: {
      fontScale: 0.75,
      baselineOffsetScale: 0.20,
    },
    highlight: {
      backgroundColor: '#FEF08A',
    },
  }}
/>
```

> [!NOTE]
> **Performance:** Memoize the `markdownStyle` prop with `useMemo` to avoid unnecessary re-renders:
> ```tsx
> import type { MarkdownStyle } from 'react-native-enriched-markdown';
>
> const markdownStyle: MarkdownStyle = useMemo(() => ({
>   paragraph: { fontSize: 16 },
>   h1: { fontSize: 32 },
> }), []);
> ```

## Dark Mode

The library ships with light-mode color defaults. It does not include a `colorScheme` prop — just like React Native's `Text`, theming is left to the consumer.

To support dark mode, create `MarkdownStyle` objects for each color scheme and switch between them using `useColorScheme()`. Your values always win over the defaults — you only need to specify the colors you want to change:

```tsx
import { useColorScheme } from 'react-native';
import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import type { MarkdownStyle } from 'react-native-enriched-markdown';

const lightMarkdownStyle: MarkdownStyle = {
  blockquote: { backgroundColor: '#F9FAFB', borderColor: '#D1D5DB' },
  code: { color: '#E01E5A', backgroundColor: '#FDF2F4' },
  table: {
    headerBackgroundColor: '#F3F4F6',
    rowEvenBackgroundColor: '#FFFFFF',
    rowOddBackgroundColor: '#F9FAFB',
  },
  // ... override any other colors for light mode
};

const darkMarkdownStyle: MarkdownStyle = {
  paragraph: { color: '#E5E7EB' },
  blockquote: { backgroundColor: '#1F2937', borderColor: '#4B5563' },
  code: { color: '#F87171', backgroundColor: '#1F2937' },
  table: {
    headerBackgroundColor: '#1F2937',
    rowEvenBackgroundColor: '#111827',
    rowOddBackgroundColor: '#1A1A2E',
    borderColor: '#374151',
  },
  // ... override any other colors for dark mode
};

function App() {
  const colorScheme = useColorScheme();

  return (
    <EnrichedMarkdownText
      markdown={content}
      markdownStyle={colorScheme === 'dark' ? darkMarkdownStyle : lightMarkdownStyle}
    />
  );
}
```

> [!NOTE]
> **Performance:** Define style objects outside the component (as shown above) or wrap them in `useMemo` so the same object reference is reused across renders.

## Style Properties Reference

### Block Styles (paragraph, h1-h6, blockquote, list, codeBlock)

| Property | Type | Description |
|----------|------|-------------|
| `fontSize` | `number` | Font size in points |
| `fontFamily` | `string` | Font family name |
| `fontWeight` | `string` | Font weight |
| `color` | `string` | Text color |
| `marginTop` | `number` | Top margin |
| `marginBottom` | `number` | Bottom margin |
| `lineHeight` | `number` | Line height |

### Paragraph and Heading-specific (paragraph, h1-h6)

| Property | Type | Description |
|----------|------|-------------|
| `textAlign` | `'auto' \| 'left' \| 'right' \| 'center' \| 'justify'` | Text alignment (default: `'left'`) |

### Blockquote-specific

| Property | Type | Description |
|----------|------|-------------|
| `borderColor` | `string` | Left border color |
| `borderWidth` | `number` | Left border width |
| `gapWidth` | `number` | Gap between border and text |
| `backgroundColor` | `string` | Background color |
| `borderRadius` | `number` | Corner radius of the background box; accent borders are clipped to the rounded shape, nested quotes rounding against their own box (default: `0`) |
| `padding` | `number` | Inner top/bottom padding between the background edges and content, applied at every nesting level — also applies to the trailing edge on iOS and web (default: `0`) |

### List-specific

| Property | Type | Description |
|----------|------|-------------|
| `bulletColor` | `string` | Bullet point color |
| `bulletSize` | `number` | Bullet point size |
| `markerMinWidth` | `number` | Minimum reserved marker column width (floors the natural width of every list type) |
| `markerColor` | `string` | Number marker color |
| `markerFontWeight` | `string` | Number marker font weight |
| `gapWidth` | `number` | Gap between marker and text |
| `marginLeft` | `number` | Left margin for nesting |
| `itemSpacing` | `number` | Vertical spacing between consecutive items, including nested ones (default: `0`) |

### Code Block-specific

| Property | Type | Description |
|----------|------|-------------|
| `backgroundColor` | `string` | Background color |
| `borderColor` | `string` | Border color |
| `borderRadius` | `number` | Corner radius |
| `borderWidth` | `number` | Border width |
| `padding` | `number` | Inner padding |
| `syntaxColors` | `object` | Per-token syntax highlight colors (see below) |

#### `syntaxColors`

Per-token foreground colors for syntax highlighting, keyed on the highlight token type. Any key you omit falls back to the default GitHub-light palette; `operator`, `punctuation`, `variable`, and `embedded` default to the code block's base `color` (i.e. no visible recolor). Colors only take visible effect when the optional syntax highlighting module is compiled in; otherwise code blocks render uncolored.

| Property | Type | Description |
|----------|------|-------------|
| `keyword` | `string` | Keywords (e.g. `if`, `return`) |
| `operator` | `string` | Operators (e.g. `+`, `=>`) |
| `punctuation` | `string` | Brackets, delimiters, punctuation |
| `string` | `string` | String and character literals |
| `number` | `string` | Numeric literals |
| `constant` | `string` | Constants and booleans |
| `comment` | `string` | Comments |
| `function` | `string` | Function and method names |
| `type` | `string` | Types and classes |
| `variable` | `string` | Variables and parameters |
| `property` | `string` | Object properties and fields |
| `tag` | `string` | Markup tags |
| `attribute` | `string` | Markup attributes |
| `embedded` | `string` | Embedded/injected language regions |

> [!NOTE]
> Inside list items, code blocks (background included) indent to the item's content column.

> [!NOTE]
> With `flavor="github"`, code blocks render as a block component with a header bar (language name on the left, copy-code button on the right) and a divider above the code. The header derives its appearance from the code block style: the label uses the system font at 0.85 x `fontSize`, and the label, button, and divider use `color` at reduced opacity. Dedicated header style properties may be added later.

### Inline Code-specific

| Property | Type | Description |
|----------|------|-------------|
| `fontFamily` | `string` | Font family for inline code. Uses the exact font face as-is. When not set, uses the platform's system monospace font (SF Mono on iOS, monospace on Android) |
| `fontSize` | `number` | Font size in points. Defaults to the parent block's font size (1em). Set to customize the monospaced font size independently |
| `color` | `string` | Text color |
| `backgroundColor` | `string` | Background color |
| `borderColor` | `string` | Border color |

### Link-specific

| Property | Type | Description |
|----------|------|-------------|
| `fontFamily` | `string` | Font family for links. Overrides the parent block's font family when set |
| `color` | `string` | Link text color |
| `underline` | `boolean` | Show underline |

### Strong-specific

| Property | Type | Description |
|----------|------|-------------|
| `fontFamily` | `string` | Font family for bold text. When not set, adds the bold trait to the parent block's font |
| `fontWeight` | `'bold' \| 'normal'` | Controls whether bold is applied on top of the custom `fontFamily`. Defaults to `'bold'`. Set to `'normal'` to use the font face as-is. Only relevant when `fontFamily` is set |
| `color` | `string` | Bold text color |

### Emphasis-specific

| Property | Type | Description |
|----------|------|-------------|
| `fontFamily` | `string` | Font family for italic text. When not set, adds the italic trait to the parent block's font |
| `fontStyle` | `'italic' \| 'normal'` | Controls whether italic is applied on top of the custom `fontFamily`. Defaults to `'italic'`. Set to `'normal'` to use the font face as-is. Only relevant when `fontFamily` is set |
| `color` | `string` | Italic text color |

### Strikethrough-specific

| Property | Type | Description |
|----------|------|-------------|
| `color` | `string` | Strikethrough line color (iOS only) |

### Underline-specific

| Property | Type | Description |
|----------|------|-------------|
| `color` | `string` | Underline color (iOS only) |

### Highlight-specific

Styles for highlighted text (`==text==`). Requires `md4cFlags={{ highlight: true }}` to enable the parser. Font size, family, and weight inherit from the surrounding block; only `color` and `backgroundColor` are overridden.

| Property | Type | Description |
|----------|------|-------------|
| `color` | `string` | Text color inside the highlight. Inherits the block color when omitted |
| `backgroundColor` | `string` | Background color of the highlight span. Default: `#FEF08A` |

```tsx
<EnrichedMarkdownText
  markdown="This is ==important== text with ==**bold**== inside."
  md4cFlags={{ highlight: true }}
  markdownStyle={{
    highlight: {
      backgroundColor: '#FEF08A',
    },
  }}
/>
```

> [!NOTE]
> When `highlight.color` is omitted, it inherits the surrounding block color. When set explicitly, it applies to the entire `==...==` span, including nested bold or italic text. Nested formatting (bold, italic, links) is preserved.

### Image-specific

| Property | Type | Description |
|----------|------|-------------|
| `height` | `number` | Fixed image height (default sizing knob). |
| `maxHeight` | `number` | Maximum height the image is fitted into, preserving aspect ratio. Replaces `height` when set. |
| `aspectRatio` | `number` | Width / height ratio (e.g. `16 / 9`). Fills available width; height derived from the ratio. Ignores `height`/`maxHeight`. |
| `resizeMode` | `'contain' \| 'cover' \| 'stretch' \| 'center' \| 'none'` | How the image fills its box (like RN `resizeMode` / CSS `object-fit`). Applies whenever set explicitly, including with a fixed `height` box. When omitted, defaults to `'cover'` if `maxHeight` or `aspectRatio` is set; otherwise block images keep the legacy fill-width behavior. |
| `borderRadius` | `number` | Corner radius |
| `marginTop` | `number` | Top margin |
| `marginBottom` | `number` | Bottom margin |

> Sizing precedence: `aspectRatio` > `maxHeight` > `height`. `resizeMode` applies independently on top. When no new knob is set (`resizeMode`, `maxHeight`, or `aspectRatio`), block images keep the exact legacy fixed-`height` behavior.

### Inline Image-specific

| Property | Type | Description |
|----------|------|-------------|
| `size` | `number` | Image size (square) |

### Thematic Break (Horizontal Rule)-specific

| Property | Type | Description |
|----------|------|-------------|
| `color` | `string` | Line color |
| `height` | `number` | Line thickness |
| `marginTop` | `number` | Top margin |
| `marginBottom` | `number` | Bottom margin |

### Table-specific

Table styles only apply when `flavor="github"` is set. Tables inherit the base block styles (`fontSize`, `fontFamily`, `fontWeight`, `color`, `marginTop`, `marginBottom`, `lineHeight`) and add the following:

| Property | Type | Description |
|----------|------|-------------|
| `headerFontFamily` | `string` | Font family for header cells (falls back to `fontFamily` if not set) |
| `headerBackgroundColor` | `string` | Background color for the header row |
| `headerTextColor` | `string` | Text color for the header row |
| `rowEvenBackgroundColor` | `string` | Background color for even data rows |
| `rowOddBackgroundColor` | `string` | Background color for odd data rows |
| `borderColor` | `string` | Color of the table grid lines |
| `borderWidth` | `number` | Width of the table grid lines |
| `borderRadius` | `number` | Corner radius of the table container |
| `cellPaddingHorizontal` | `number` | Horizontal padding inside cells |
| `cellPaddingVertical` | `number` | Vertical padding inside cells |
| `horizontalOverflow` | `number` | When set, scrollable tables extend beyond the markdown container by this amount on each side (edge-to-edge / "bleed" layout). Set to the parent's horizontal padding to make wide tables reach the screen edges. Has no effect on tables that fit within the container width. iOS, Android, and macOS only. Default: `0` |
| `align` | `'left' \| 'center' \| 'right'` | Horizontal alignment of the whole table when it is narrower than the container. Tables that overflow and scroll ignore it — scrolling always starts at the table's beginning. On web, setting any value (including `'left'`) also makes the table shrink to fit its content instead of filling the container width. Default: unset — legacy start-aligned placement (full-width table on web) |

### Task List-specific

| Property | Type | Description |
|----------|------|-------------|
| `checkedColor` | `string` | Background color of checked checkbox |
| `borderColor` | `string` | Border color of unchecked checkbox |
| `checkmarkColor` | `string` | Color of the checkmark inside checked checkbox |
| `checkboxSize` | `number` | Size of the checkbox (defaults to 90% of list font size) |
| `checkboxBorderRadius` | `number` | Corner radius of the checkbox |
| `checkedTextColor` | `string` | Text color for checked items |
| `checkedStrikethrough` | `boolean` | Whether to apply strikethrough to checked items |

### Math Block-specific

Styles for block-level LaTeX math (`$$...$$`). Block math is rendered as a standalone display element and only applies when `flavor="github"` is set.

| Property | Type | Description |
|----------|------|-------------|
| `fontSize` | `number` | Font size used when rendering the equation |
| `color` | `string` | Equation text color |
| `backgroundColor` | `string` | Background color of the math block container |
| `padding` | `number` | Inner padding around the equation |
| `marginTop` | `number` | Top margin |
| `marginBottom` | `number` | Bottom margin |
| `textAlign` | `'left' \| 'center' \| 'right'` | Horizontal alignment of the equation (default: `'center'`) |

### Inline Math-specific

Styles for inline LaTeX math (`$...$`). Inline math is rendered within the surrounding text flow.

| Property | Type | Description |
|----------|------|-------------|
| `color` | `string` | Equation text color |

### Spoiler-specific

Styles for spoiler text (`||hidden text||`). Spoiler text is concealed behind an overlay (controlled by the `spoilerOverlay` prop) until the user taps to reveal it.

| Property | Type | Description |
|----------|------|-------------|
| `color` | `string` | Color used by all presets for the spoiler overlay |
| `particles.density` | `number` | Density of the particle field (higher = more particles). Default: `8` |
| `particles.speed` | `number` | Speed of particle movement. Default: `20` |
| `solid.borderRadius` | `number` | Corner radius of the solid spoiler overlay rectangles. Default: `4` |

### Superscript-specific

Styles for superscript text (`^text^`). Requires `md4cFlags={{ superscript: true }}` to enable the parser.

| Property | Type | Description |
|----------|------|-------------|
| `fontScale` | `number` | Font size as a fraction of the surrounding text size. Default: `0.75` (iOS/macOS/web), `0.65` (Android) |
| `baselineOffsetScale` | `number` | Vertical shift upward as a fraction of the surrounding text size. Default: `0.35` |

```tsx
<EnrichedMarkdownText
  markdown="E = mc^2^"
  md4cFlags={{ superscript: true }}
  markdownStyle={{
    superscript: {
      fontScale: 0.75,
      baselineOffsetScale: 0.35,
    },
  }}
/>
```

### Subscript-specific

Styles for subscript text (`~text~`). Requires `md4cFlags={{ subscript: true }}` to enable the parser. Note: enabling subscript changes the behaviour of single tildes — `~text~` becomes subscript instead of strikethrough.

| Property | Type | Description |
|----------|------|-------------|
| `fontScale` | `number` | Font size as a fraction of the surrounding text size. Default: `0.75` (iOS/macOS/web), `0.65` (Android) |
| `baselineOffsetScale` | `number` | Vertical shift downward as a fraction of the surrounding text size. Default: `0.20` |

```tsx
<EnrichedMarkdownText
  markdown="H~2~O"
  md4cFlags={{ subscript: true }}
  markdownStyle={{
    subscript: {
      fontScale: 0.75,
      baselineOffsetScale: 0.20,
    },
  }}
/>
```

> [!NOTE]
> Android uses a slightly smaller default `fontScale` (`0.65`) compared to iOS (`0.75`) because Roboto has a larger x-height than San Francisco, making identically-scaled text appear visually larger on Android.
