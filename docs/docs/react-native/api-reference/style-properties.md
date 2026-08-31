---
sidebar_label: Style properties
sidebar_position: 3
---

import InteractiveExample from '@site/src/components/InteractiveExample';
import LivePreview from '@site/src/components/LivePreview';
import FirstText from '@site/src/examples/react-native/basics/your-first-project/FirstText';
import FirstTextSrc from '!!raw-loader!@site/src/examples/react-native/basics/your-first-project/FirstText';

import CustomThemeSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/style-properties/CustomTheme';
import InheritanceSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/style-properties/Inheritance';
import HeadingsSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/style-properties/Headings';
import InlineStylesSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/style-properties/InlineStyles';
import CodeBlockSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/style-properties/CodeBlock';
import BlockquoteSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/style-properties/Blockquote';
import ListSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/style-properties/List';
import TaskListSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/style-properties/TaskList';
import TableSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/style-properties/Table';
import HighlightSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/style-properties/Highlight';
import ThematicBreakSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/style-properties/ThematicBreak';

# Style properties reference

:::caution
THIS PAGE IS WORK IN PROGRESS
:::

This page provides a comprehensive reference for all style properties available in `react-native-enriched-markdown`, passed through the `markdownStyle` prop.

:::important
Unless noted otherwise, this reference covers the read-only [`EnrichedMarkdownText`](/react-native/api-reference/enriched-markdown-text) renderer and its `MarkdownStyle`. The editable [`EnrichedMarkdownTextInput`](/react-native/api-reference/enriched-markdown-text-input) styles a smaller subset - see [Editor styles](#editor-styles).
:::

## Platform defaults

You do not need to set anything to get a polished result. Every element ships with defaults tuned to the platform it renders on, so a document looks at home on each without configuration:

- **Fonts.** Text uses the platform system font (San Francisco on iOS, Roboto on Android). Inline code and code blocks use the platform monospace font (SF Mono on iOS, monospace on Android).
- **Spacing.** Line height and block margins follow each platform's text conventions, so paragraphs, headings, and lists sit at a natural rhythm out of the box.
- **Colors.** Text, links, code, blockquotes, and tables start from light-mode color defaults. See [Dark mode](#dark-mode) to switch palettes with the system color scheme.

Override any of these through `markdownStyle`: you set only the properties you want to change, and everything else keeps its default.

## Style inheritance

`react-native-enriched-markdown` uses a base block style architecture where all block elements (paragraphs, headings, lists, blockquotes, code blocks) share a common set of typography properties. This base block style includes:

- `fontSize` - font size in points
- `fontFamily` - font family name
- `fontWeight` - font weight
- `color` - text color
- `marginTop` - top margin
- `marginBottom` - bottom margin
- `lineHeight` - line height

Each block type extends this base style with its own specific properties (e.g. `textAlign` for paragraphs and headings, `borderColor` for blockquotes, `bulletColor` for lists).

### Inline style inheritance

Inline styles (strong, emphasis, links, inline code, etc.) automatically inherit the base typography properties from their containing block. This means inline elements use the block's `fontSize`, `fontFamily`, `fontWeight`, and `color` as their foundation, then apply their own additional styling on top.

In the playground below, only the two blocks set a size and color: the heading uses `fontSize: 24` with a blue `color`, the list uses `fontSize: 16` with a gray `color`. Every inline element leaves both unset, so each inherits from its block and adds only its own emphasis: **bold** and *italic* take the block size and color and add weight or slant, the link takes the size and adds its own color plus an underline, and `inline code` takes the size and color and adds only a background chip. Change a block's `color` and every inline element inside it follows.

<LivePreview src={InheritanceSrc} />

This inheritance model ensures consistent typography throughout your Markdown content while allowing inline elements to add their own visual emphasis.

### Custom font family for inline styles

Strong, emphasis, and inline code support an optional `fontFamily` property that gives you full control over the font face used for that element.

**Default behavior (no `fontFamily` set):**

- **Strong** - adds the bold trait to the current block font
- **Emphasis** - adds the italic trait to the current block font
- **Inline code** - uses the platform's system monospace font (SF Mono on iOS, monospace on Android)

**With `fontFamily` set:**

By default, bold/italic traits are still applied on top of the custom font family. Use `fontWeight: 'normal'` or `fontStyle: 'normal'` to disable this and use the font face exactly as-is:

```tsx
markdownStyle={{
  strong: {
    // Bold trait is applied on top of Montserrat-Bold (default: fontWeight 'bold')
    fontFamily: 'Montserrat-Bold',
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

## Customizing styles

The library provides sensible default styles for all Markdown elements out of the box. You override any of them through the `markdownStyle` prop - only the properties you name change, everything else keeps its default. The playground below starts from the shared palette and restyles a heading, links, and the blockquote accent; edit it to see how each key maps to the rendered output.

<LivePreview src={CustomThemeSrc} />

:::note
**Performance:** Memoize the `markdownStyle` prop with `useMemo` to avoid unnecessary re-renders:

```tsx
import type { MarkdownStyle } from 'react-native-enriched-markdown';

const markdownStyle: MarkdownStyle = useMemo(() => ({
  paragraph: { fontSize: 16 },
  h1: { fontSize: 32 },
}), []);
```
:::

## Dark mode

The library ships with light-mode color defaults. It does not include a `colorScheme` prop - just like React Native's `Text`, theming is left to the consumer.

To support dark mode, create `MarkdownStyle` objects for each color scheme and switch between them using `useColorScheme()`. Your values always win over the defaults - you only need to specify the colors you want to change:

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

:::note
**Performance:** Define style objects outside the component (as shown above) or wrap them in `useMemo` so the same object reference is reused across renders.
:::

## Property reference

### Block styles (paragraph, h1–h6, blockquote, list, codeBlock)

| Property | Type | Description |
|----------|------|-------------|
| `fontSize` | `number` | Font size in points |
| `fontFamily` | `string` | Font family name |
| `fontWeight` | `string` | Font weight |
| `color` | `string` | Text color |
| `marginTop` | `number` | Top margin |
| `marginBottom` | `number` | Bottom margin |
| `lineHeight` | `number` | Line height |

### Paragraph and heading-specific (paragraph, h1–h6)

| Property | Type | Description |
|----------|------|-------------|
| `textAlign` | `'auto' \| 'left' \| 'right' \| 'center' \| 'justify'` | Text alignment (default: `'left'`) |

Each heading level (`h1`–`h6`) and `paragraph` is styled by its own key. Give each level its own size and color.

<LivePreview src={HeadingsSrc} />

### Blockquote-specific

| Property | Type | Description |
|----------|------|-------------|
| `borderColor` | `string` | Left border color |
| `borderWidth` | `number` | Left border width |
| `gapWidth` | `number` | Gap between border and text |
| `backgroundColor` | `string` | Background color |

<LivePreview src={BlockquoteSrc} />

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

<LivePreview src={ListSrc} />

### Code block-specific

| Property | Type | Description |
|----------|------|-------------|
| `backgroundColor` | `string` | Background color |
| `borderColor` | `string` | Border color |
| `borderRadius` | `number` | Corner radius |
| `borderWidth` | `number` | Border width |
| `padding` | `number` | Inner padding |

:::note
Inside list items, code blocks (background included) indent to the item's content column.
:::

<LivePreview src={CodeBlockSrc} />

### Inline code-specific

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

The inline elements (`strong`, `em`, `link`, `code`) inherit the surrounding block's typography and add their own color on top. The playground restyles all four at once.

<LivePreview src={InlineStylesSrc} />

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

<LivePreview src={HighlightSrc} />

### Image-specific

| Property | Type | Description |
|----------|------|-------------|
| `height` | `number` | Image height |
| `borderRadius` | `number` | Corner radius |
| `marginTop` | `number` | Top margin |
| `marginBottom` | `number` | Bottom margin |

### Inline image-specific

| Property | Type | Description |
|----------|------|-------------|
| `size` | `number` | Image size (square) |

### Thematic break (horizontal rule)-specific

| Property | Type | Description |
|----------|------|-------------|
| `color` | `string` | Line color |
| `height` | `number` | Line thickness |
| `marginTop` | `number` | Top margin |
| `marginBottom` | `number` | Bottom margin |

<LivePreview src={ThematicBreakSrc} />

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

<LivePreview src={TableSrc} />

### Task list-specific

| Property | Type | Description |
|----------|------|-------------|
| `checkedColor` | `string` | Background color of checked checkbox |
| `borderColor` | `string` | Border color of unchecked checkbox |
| `checkmarkColor` | `string` | Color of the checkmark inside checked checkbox |
| `checkboxSize` | `number` | Size of the checkbox (defaults to 90% of list font size) |
| `checkboxBorderRadius` | `number` | Corner radius of the checkbox |
| `checkedTextColor` | `string` | Text color for checked items |
| `checkedStrikethrough` | `boolean` | Whether to apply strikethrough to checked items |

<LivePreview src={TaskListSrc} />

### Math block-specific

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

### Inline math-specific

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

### Subscript-specific

Styles for subscript text (`~text~`). Requires `md4cFlags={{ subscript: true }}` to enable the parser. Note: enabling subscript changes the behavior of single tildes - `~text~` becomes subscript instead of strikethrough.

| Property | Type | Description |
|----------|------|-------------|
| `fontScale` | `number` | Font size as a fraction of the surrounding text size. Default: `0.75` (iOS/macOS/web), `0.65` (Android) |
| `baselineOffsetScale` | `number` | Vertical shift downward as a fraction of the surrounding text size. Default: `0.20` |

:::note
Android uses a slightly smaller default `fontScale` (`0.65`) compared to iOS (`0.75`) because Roboto has a larger x-height than San Francisco, making identically-scaled text appear visually larger on Android.
:::

## Editor styles (`EnrichedMarkdownTextInput`) {#editor-styles}

The editable [`EnrichedMarkdownTextInput`](/react-native/api-reference/enriched-markdown-text-input) takes its own `markdownStyle` of type `MarkdownTextInputStyle`. It is a **subset** of the renderer's `MarkdownStyle` documented above: the editor supports inline formatting, links, spoilers, and headings, so only those elements are styleable - there is no `paragraph`, `code`, `blockquote`, `table`, and so on. Every field is optional and falls back to a default that matches the renderer, so content looks the same while editing and once rendered.

The base text appearance (font size, family, color) comes from the input's [`style`](/react-native/api-reference/enriched-markdown-text-input#style) prop, not from `markdownStyle`.

| Property | Type | Description |
|----------|------|-------------|
| `strong.color` | `string` | Bold text color. Defaults to the input's text color |
| `em.color` | `string` | Italic text color. Defaults to the input's text color |
| `link.color` | `string` | Link text color. Default: `#2563EB` |
| `link.underline` | `boolean` | Whether links are underlined. Default: `true` |
| `link.backgroundColor` | `string` | Link background color. Default: `transparent` |
| `linkVariants` | `Record<string, LinkStyle>` | Per-URL-pattern style overrides. Each key is a regex tested against the link URL; see [Mentions - Link variants](/rich-text-formatting/mentions) |
| `spoiler.color` | `string` | Spoiler text color |
| `spoiler.backgroundColor` | `string` | Spoiler background color |
| `h1`–`h6` | `{ fontSize?, fontWeight?, color? }` | Per-level heading styling. Defaults match the renderer (sizes `30/24/20/18/16/14`, bold); omitted levels or fields fall back to those defaults |
| `list.itemSpacing` | `number` | Vertical spacing (points) added above each list item (bullet and numbered alike) so items read as separate rows. Default: `0` |

## Try it yourself

The example below sets a custom `markdownStyle`. Switch to the Code tab and tweak the values to see how each property changes the rendered output.

<InteractiveExample src={FirstTextSrc} component={FirstText} />
