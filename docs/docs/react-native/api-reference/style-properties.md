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
import CodeBlockSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/style-properties/CodeBlock';
import BlockquoteSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/style-properties/Blockquote';
import ListSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/style-properties/List';
import TaskListSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/style-properties/TaskList';
import TableSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/style-properties/Table';
import HighlightSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/style-properties/Highlight';
import ThematicBreakSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/style-properties/ThematicBreak';
import DarkModeSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/style-properties/DarkMode';
import SyntaxColorsSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/style-properties/SyntaxColors';
import BaseBlockSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/style-properties/BaseBlock';
import InlineCodeSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/style-properties/InlineCode';
import LinkSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/style-properties/Link';
import StrongSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/style-properties/Strong';
import EmphasisSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/style-properties/Emphasis';
import StrikethroughSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/style-properties/Strikethrough';
import UnderlineSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/style-properties/Underline';
import ImageSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/style-properties/Image';
import InlineImageSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/style-properties/InlineImage';
import MathBlockSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/style-properties/MathBlock';
import InlineMathSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/style-properties/InlineMath';
import SuperscriptSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/style-properties/Superscript';
import SubscriptSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/style-properties/Subscript';
import SpoilerSrc from '!!raw-loader!@site/src/examples/react-native/api-reference/style-properties/Spoiler';

# Style properties reference

This page provides a comprehensive reference for all style properties available in `react-native-enriched-markdown`, passed through the `markdownStyle` prop.

:::important
Unless noted otherwise, this reference covers the read-only [`EnrichedMarkdownText`](/react-native/api-reference/enriched-markdown-text) renderer and its `MarkdownStyle`. The editable [`EnrichedMarkdownTextInput`](/react-native/api-reference/enriched-markdown-text-input) styles a smaller subset - see [Editor styles](#editor-styles).
:::

## Platform defaults

You do not need to set anything to get a polished result. Every element ships with defaults tuned to the platform it renders on, so a document looks at home on each without configuration:

- **Fonts.** Text uses the platform system font (San Francisco on iOS, Roboto on Android). Inline code and code blocks use the platform monospace font (SF Mono on iOS, monospace on Android).
- **Spacing.** Line height and block margins follow each platform's text conventions, so paragraphs, headings, and lists sit at a natural rhythm out of the box.
- **Colors.** Text, links, code, blockquotes, and tables start from light-mode color defaults. See [Dark mode](#dark-mode) to switch palettes with the system color scheme.

Override any of these through `markdownStyle` prop. You set only the properties you want to change, and everything else keeps its default.

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

In the playground below, only the two blocks set a size and color: the heading uses `fontSize: 24` with a blue `color`, the list uses `fontSize: 16` with a gray `color`. Every inline element leaves both unset, so each inherits from its block and adds only its own emphasis: **bold** and _italic_ take the block size and color and add weight or slant, the link takes the size and adds its own color plus an underline, and `inline code` takes the size and color and adds only a background chip. Change a block's `color` and every inline element inside it follows.

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

:::tip
Memoize the `markdownStyle` prop with `useMemo` to avoid unnecessary re-renders:

```tsx
import type { MarkdownStyle } from 'react-native-enriched-markdown';

const markdownStyle: MarkdownStyle = useMemo(
  () => ({
    paragraph: { fontSize: 16 },
    h1: { fontSize: 32 },
  }),
  [],
);
```

:::

## Dark mode

The library ships with light-mode color defaults. It does not include a `colorScheme` prop - just like React Native's `Text`, theming is left to the consumer.

To support dark mode, create `MarkdownStyle` objects for each color scheme and switch between them using `useColorScheme()`. Your values always win over the defaults - you only need to specify the colors you want to change:

<LivePreview src={DarkModeSrc} />

As you may have noticed in the other examples throughout this documentation, every interactive playground already follows the same color scheme as this page: each one derives an `isDark` flag from `useColorScheme()` and picks its palette from it, so toggling the site between light and dark re-themes the preview live. The example above does the same with two hand-authored palettes; edit either object in the Code tab and flip the site theme to see the switch happen.

## Property reference

### Block styles (paragraph, h1-h6, blockquote, list, codeBlock)

| Property       | Type     | Default                 | Description         |
| -------------- | -------- | ----------------------- | ------------------- |
| `fontSize`     | `number` | `16`                    | Font size in points |
| `fontFamily`   | `string` | System font             | Font family name    |
| `fontWeight`   | `string` | `normal`                | Font weight         |
| `color`        | `string` | `#1F2937`               | Text color          |
| `marginTop`    | `number` | `0`                     | Top margin          |
| `marginBottom` | `number` | `16`                    | Bottom margin       |
| `lineHeight`   | `number` | `24` iOS / `26` Android | Line height         |

These properties are shared by every block element - set any of them on a `paragraph`, `h1`-`h6`, `blockquote`, `list`, or `codeBlock` key. The defaults above are the `paragraph` (body) values; other block types override several of them - headings use sizes `30/24/20/18/16/14` at weight `bold` with an `8` bottom margin, `codeBlock` uses the monospace font and `table` the system font both at size `14`, and `blockquote` uses color `#4B5563`. The playground below sets these on a heading and a paragraph; the element-specific sections that follow layer their own properties on top.

<LivePreview src={BaseBlockSrc} />

### Paragraph and heading-specific (paragraph, h1-h6)

| Property    | Type                                                   | Default  | Description    |
| ----------- | ------------------------------------------------------ | -------- | -------------- |
| `textAlign` | `'auto' \| 'left' \| 'right' \| 'center' \| 'justify'` | `'auto'` | Text alignment |

Each heading level (`h1`–`h6`) and `paragraph` is styled by its own key. Give each level its own size and color.

<LivePreview src={HeadingsSrc} />

### Blockquote-specific

| Property          | Type     | Default   | Description                              |
| ----------------- | -------- | --------- | ---------------------------------------- |
| `borderColor`     | `string` | `#D1D5DB` | Left border color                        |
| `borderWidth`     | `number` | `3`       | Left border width                        |
| `gapWidth`        | `number` | `16`      | Gap between border and text              |
| `backgroundColor` | `string` | `#F9FAFB` | Background color                         |
| `borderRadius`    | `number` | `0`       | Corner radius of the blockquote box      |
| `padding`         | `number` | `0`       | Inner padding around the blockquote text |

<LivePreview src={BlockquoteSrc} />

### List-specific

| Property           | Type     | Default   | Description                                                                                                                         |
| ------------------ | -------- | --------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| `bulletColor`      | `string` | `#6B7280` | Bullet point color                                                                                                                  |
| `bulletSize`       | `number` | `6`       | Bullet point size                                                                                                                   |
| `markerMinWidth`   | `number` | `0`       | Minimum reserved marker column width (floors the natural width of every list type)                                                  |
| `markerColor`      | `string` | `#6B7280` | Number marker color                                                                                                                 |
| `markerFontWeight` | `string` | `'500'`   | Number marker font weight                                                                                                           |
| `gapWidth`         | `number` | `12`      | Gap between marker and text                                                                                                         |
| `marginLeft`       | `number` | `24`      | Left margin for nesting                                                                                                             |
| `itemSpacing`      | `number` | `0`       | Vertical spacing added between consecutive list items (including nested ones). Adds no space above the first item or below the last |

:::note
On web, lists render with the browser's native bullets and numbers, so the marker styling props - `bulletColor`, `bulletSize`, `markerColor`, `markerFontWeight`, `markerMinWidth`, and `gapWidth` - have no effect there. `marginLeft` and `itemSpacing` still apply on all platforms.
:::

<LivePreview src={ListSrc} />

### Code block-specific

| Property          | Type                    | Default             | Description                                                                           |
| ----------------- | ----------------------- | ------------------- | ------------------------------------------------------------------------------------- |
| `backgroundColor` | `string`                | `#1F2937`           | Background color                                                                      |
| `borderColor`     | `string`                | `#374151`           | Border color                                                                          |
| `borderRadius`    | `number`                | `8`                 | Corner radius                                                                         |
| `borderWidth`     | `number`                | `1`                 | Border width                                                                          |
| `padding`         | `number`                | `16`                | Inner padding                                                                         |
| `syntaxColors`    | `CodeBlockSyntaxColors` | GitHub-dark palette | Per-token syntax highlight colors. To learn more, see [Syntax colors](#syntax-colors) |

:::note
Inside list items, code blocks (background included) indent to the item's content column.
:::

<LivePreview src={CodeBlockSrc} />

#### Syntax colors

The `syntaxColors` key sets a color per syntax token type for fenced code blocks, keyed on the [tree-sitter](https://tree-sitter.github.io/tree-sitter/) highlight token names. Pass only the tokens you want to recolor; any key you omit falls back to the default palette. Four tokens - `operator`, `punctuation`, `variable`, and `embedded` - inherit the code block's base `color` by default rather than a fixed palette value.

To learn more about how code highlighting works, see the [Code highlighting](/rich-text-formatting/code-highlighting) guide.

| Token         | Default      | Description                                                                                |
| ------------- | ------------ | ------------------------------------------------------------------------------------------ |
| `keyword`     | `#FF7B72`    | Language keywords (e.g. `if`, `return`, `const`)                                           |
| `operator`    | Base `color` | Operators (e.g. `+`, `=>`). Inherits the base `color` when omitted                         |
| `punctuation` | Base `color` | Punctuation such as braces, commas, and semicolons. Inherits the base `color` when omitted |
| `string`      | `#A5D6FF`    | String literals                                                                            |
| `number`      | `#79C0FF`    | Numeric literals                                                                           |
| `constant`    | `#79C0FF`    | Constants (e.g. `true`, `null`)                                                            |
| `comment`     | `#8B949E`    | Comments                                                                                   |
| `function`    | `#D2A8FF`    | Function names                                                                             |
| `type`        | `#FFA657`    | Type names                                                                                 |
| `variable`    | Base `color` | Variables. Inherits the base `color` when omitted                                          |
| `property`    | `#79C0FF`    | Object properties and fields                                                               |
| `tag`         | `#7EE787`    | Markup tags (e.g. HTML or JSX element names)                                               |
| `attribute`   | `#79C0FF`    | Markup attributes                                                                          |
| `embedded`    | Base `color` | Embedded content such as interpolations. Inherits the base `color` when omitted            |

:::note
Syntax colors only take visible effect when the optional syntax-highlighting module is compiled in; otherwise code blocks render uncolored. The module is native-only, so `syntaxColors` has no effect on the web build.
:::

<LivePreview src={SyntaxColorsSrc} unavailable unavailableLabel="Needs native highlighter" unavailableReason={<>iOS and Android only, and only with the syntax-highlighting module compiled in - the web build does not highlight code, so <code>syntaxColors</code> has no visible effect here. The source is shown for reference.</>} />

### Inline code-specific

| Property          | Type     | Default                 | Description                                                                                                                                                 |
| ----------------- | -------- | ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `fontFamily`      | `string` | System monospace        | Font family for inline code. Uses the exact font face as-is. When not set, uses the platform's system monospace font (SF Mono on iOS, monospace on Android) |
| `fontSize`        | `number` | Parent block size (1em) | Font size in points. Set to customize the monospaced font size independently                                                                                |
| `color`           | `string` | `#E01E5A`               | Text color                                                                                                                                                  |
| `backgroundColor` | `string` | `#FDF2F4`               | Background color                                                                                                                                            |
| `borderColor`     | `string` | `#F8D7DA`               | Border color                                                                                                                                                |

<LivePreview src={InlineCodeSrc} />

### Link-specific

| Property          | Type      | Default        | Description                                                              |
| ----------------- | --------- | -------------- | ------------------------------------------------------------------------ |
| `fontFamily`      | `string`  | Inherits block | Font family for links. Overrides the parent block's font family when set |
| `color`           | `string`  | `#2563EB`      | Link text color                                                          |
| `underline`       | `boolean` | `true`         | Show underline                                                           |
| `backgroundColor` | `string`  | `transparent`  | Link background color                                                    |

You can also style links per URL pattern through the top-level `linkVariants` key (a `Record<string, LinkStyle>` whose keys are regexes tested against the link URL). See [Mentions - Link variants](/rich-text-formatting/mentions).

<LivePreview src={LinkSrc} />

### Strong-specific

| Property     | Type                 | Default        | Description                                                                                                                                              |
| ------------ | -------------------- | -------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `fontFamily` | `string`             | Inherits block | Font family for bold text. When not set, adds the bold trait to the parent block's font                                                                  |
| `fontWeight` | `'bold' \| 'normal'` | `'bold'`       | Controls whether bold is applied on top of the custom `fontFamily`. Set to `'normal'` to use the font face as-is. Only relevant when `fontFamily` is set |
| `color`      | `string`             | Inherits block | Bold text color                                                                                                                                          |

<LivePreview src={StrongSrc} />

### Emphasis-specific

| Property     | Type                   | Default        | Description                                                                                                                                                |
| ------------ | ---------------------- | -------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `fontFamily` | `string`               | Inherits block | Font family for italic text. When not set, adds the italic trait to the parent block's font                                                                |
| `fontStyle`  | `'italic' \| 'normal'` | `'italic'`     | Controls whether italic is applied on top of the custom `fontFamily`. Set to `'normal'` to use the font face as-is. Only relevant when `fontFamily` is set |
| `color`      | `string`               | Inherits block | Italic text color                                                                                                                                          |

The inline elements (`strong`, `em`, `link`, `code`) inherit the surrounding block's typography and add their own color on top.

<LivePreview src={EmphasisSrc} />

### Strikethrough-specific

| Property | Type     | Default   | Description                                                                       |
| -------- | -------- | --------- | --------------------------------------------------------------------------------- |
| `color`  | `string` | `#9CA3AF` | Strikethrough line color (iOS and web; on Android the strike uses the text color) |

<LivePreview src={StrikethroughSrc} />

### Underline-specific

Requires [`md4cFlags={{ underline: true }}`](/react-native/api-reference/enriched-markdown-text#underline), which makes `_text_` render as underline instead of emphasis.

| Property | Type     | Default   | Description                                                                 |
| -------- | -------- | --------- | --------------------------------------------------------------------------- |
| `color`  | `string` | `#1F2937` | Underline color (iOS and web; on Android the underline uses the text color) |

<LivePreview src={UnderlineSrc} />

### Highlight-specific

Styles for highlighted text (`==text==`). Requires [`md4cFlags={{ highlight: true }}`](/react-native/api-reference/enriched-markdown-text#highlight) to enable the parser. Font size, family, and weight inherit from the surrounding block; only `color` and `backgroundColor` are overridden.

| Property          | Type     | Default        | Description                                                            |
| ----------------- | -------- | -------------- | ---------------------------------------------------------------------- |
| `color`           | `string` | Inherits block | Text color inside the highlight. Inherits the block color when omitted |
| `backgroundColor` | `string` | `#FEF08A`      | Background color of the highlight span                                 |

<LivePreview src={HighlightSrc} />

### Image-specific

| Property       | Type                                                      | Default                                                 | Description                                                                                                             |
| -------------- | --------------------------------------------------------- | ------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `height`       | `number`                                                  | `200`                                                   | Fixed image height                                                                                                      |
| `maxHeight`    | `number`                                                  | unset                                                   | Maximum height the image is fitted into, preserving aspect ratio. Replaces `height` as the primary sizing knob when set |
| `aspectRatio`  | `number`                                                  | unset                                                   | Width / height ratio (e.g. `16 / 9`). The image fills the available width and derives its height from this ratio        |
| `resizeMode`   | `'contain' \| 'cover' \| 'stretch' \| 'center' \| 'none'` | unset (`'cover'` when `maxHeight`/`aspectRatio` is set) | How the image fills its box (analogous to React Native `resizeMode`)                                                    |
| `borderRadius` | `number`                                                  | `8`                                                     | Corner radius                                                                                                           |
| `marginTop`    | `number`                                                  | `0`                                                     | Top margin                                                                                                              |
| `marginBottom` | `number`                                                  | `16`                                                    | Bottom margin                                                                                                           |

Sizing precedence is `aspectRatio` > `maxHeight` > `height`: the first one set wins and the lower-priority knobs are ignored.

<LivePreview src={ImageSrc} />

### Inline image-specific

| Property | Type     | Default | Description         |
| -------- | -------- | ------- | ------------------- |
| `size`   | `number` | `20`    | Image size (square) |

<LivePreview src={InlineImageSrc} />

### Thematic break (horizontal rule)-specific

| Property       | Type     | Default   | Description    |
| -------------- | -------- | --------- | -------------- |
| `color`        | `string` | `#E5E7EB` | Line color     |
| `height`       | `number` | `1`       | Line thickness |
| `marginTop`    | `number` | `24`      | Top margin     |
| `marginBottom` | `number` | `24`      | Bottom margin  |

<LivePreview src={ThematicBreakSrc} />

### Table-specific

Table styles only apply when [`flavor="github"`](/react-native/api-reference/enriched-markdown-text#flavor) is set. Tables inherit the base block styles (`fontSize`, `fontFamily`, `fontWeight`, `color`, `marginTop`, `marginBottom`, `lineHeight`) and add the following:

| Property                 | Type                            | Default               | Description                                                                                                                                                                  |
| ------------------------ | ------------------------------- | --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `headerFontFamily`       | `string`                        | Inherits `fontFamily` | Font family for header cells (falls back to `fontFamily` if not set)                                                                                                         |
| `headerBackgroundColor`  | `string`                        | `#F3F4F6`             | Background color for the header row                                                                                                                                          |
| `headerTextColor`        | `string`                        | `#111827`             | Text color for the header row                                                                                                                                                |
| `rowEvenBackgroundColor` | `string`                        | `#FFFFFF`             | Background color for even data rows                                                                                                                                          |
| `rowOddBackgroundColor`  | `string`                        | `#F9FAFB`             | Background color for odd data rows                                                                                                                                           |
| `borderColor`            | `string`                        | `#E5E7EB`             | Color of the table grid lines                                                                                                                                                |
| `borderWidth`            | `number`                        | `1`                   | Width of the table grid lines                                                                                                                                                |
| `borderRadius`           | `number`                        | `6`                   | Corner radius of the table container                                                                                                                                         |
| `cellPaddingHorizontal`  | `number`                        | `12`                  | Horizontal padding inside cells                                                                                                                                              |
| `cellPaddingVertical`    | `number`                        | `8`                   | Vertical padding inside cells                                                                                                                                                |
| `horizontalOverflow`     | `number`                        | `0`                   | Extra width (points) a table may extend beyond the container edges, letting a wide table bleed into the surrounding padding as it scrolls. No effect on web                  |
| `align`                  | `'left' \| 'center' \| 'right'` | unset                 | Horizontal alignment of the whole table within the container. Only applies when the table is narrower than the container; overflowing tables always start at their beginning |

<LivePreview src={TableSrc} />

### Task list-specific

| Property               | Type      | Default                           | Description                                                      |
| ---------------------- | --------- | --------------------------------- | ---------------------------------------------------------------- |
| `checkedColor`         | `string`  | `#007AFF` iOS / `#2196F3` Android | Background color of checked checkbox                             |
| `borderColor`          | `string`  | `#9E9E9E`                         | Border color of unchecked checkbox. No effect on web             |
| `checkmarkColor`       | `string`  | `#FFFFFF`                         | Color of the checkmark inside checked checkbox. No effect on web |
| `checkboxSize`         | `number`  | 90% of list font size             | Size of the checkbox                                             |
| `checkboxBorderRadius` | `number`  | `3`                               | Corner radius of the checkbox                                    |
| `checkedTextColor`     | `string`  | `#000000`                         | Text color for checked items                                     |
| `checkedStrikethrough` | `boolean` | `false`                           | Whether to apply strikethrough to checked items                  |

:::note
On web, the checkbox is the browser's native `<input type="checkbox">` tinted via `accentColor` (`checkedColor`). Its `borderColor` and `checkmarkColor` are drawn by the browser and cannot be overridden.
:::

<LivePreview src={TaskListSrc} />

### Math block-specific

Styles for block-level LaTeX math (`$$...$$`). Block math is rendered as a standalone display element and only applies when [`flavor="github"`](/react-native/api-reference/enriched-markdown-text#flavor) is set. Rendering also requires [`md4cFlags={{ latexMath: true }}`](/react-native/api-reference/enriched-markdown-text#latexmath), which is on by default.

| Property          | Type                            | Default    | Description                                  |
| ----------------- | ------------------------------- | ---------- | -------------------------------------------- |
| `fontSize`        | `number`                        | `20`       | Font size used when rendering the equation   |
| `color`           | `string`                        | `#1F2937`  | Equation text color                          |
| `backgroundColor` | `string`                        | `#F3F4F6`  | Background color of the math block container |
| `padding`         | `number`                        | `12`       | Inner padding around the equation            |
| `marginTop`       | `number`                        | `0`        | Top margin                                   |
| `marginBottom`    | `number`                        | `16`       | Bottom margin                                |
| `textAlign`       | `'left' \| 'center' \| 'right'` | `'center'` | Horizontal alignment of the equation         |

<LivePreview src={MathBlockSrc} />

### Inline math-specific

Styles for inline LaTeX math (`$...$`). Inline math is rendered within the surrounding text flow.

| Property | Type     | Default   | Description         |
| -------- | -------- | --------- | ------------------- |
| `color`  | `string` | `#1F2937` | Equation text color |

<LivePreview src={InlineMathSrc} />

### Spoiler-specific

Styles for spoiler text (`||hidden text||`). The text is concealed behind an overlay until the user taps to reveal it.

Which overlay preset is used - `'particles'` or `'solid'` - is not a style property; it is chosen with the [`spoilerOverlay`](/react-native/api-reference/enriched-markdown-text#spoileroverlay) prop on the component. The keys below only tune appearance: `color` applies to both presets, while `particles.*` and `solid.*` each affect only their matching preset.

:::note
The spoiler overlay is iOS and Android only - the web build does not render it, so none of the spoiler style properties below have any effect on web.
:::

| Property             | Type     | Default   | Description                                             |
| -------------------- | -------- | --------- | ------------------------------------------------------- |
| `color`              | `string` | `#374151` | Color used by all presets for the spoiler overlay       |
| `particles.density`  | `number` | `8`       | Density of the particle field (higher = more particles) |
| `particles.speed`    | `number` | `20`      | Speed of particle movement                              |
| `solid.borderRadius` | `number` | `4`       | Corner radius of the solid spoiler overlay rectangles   |

<LivePreview src={SpoilerSrc} unavailable unavailableReason={<>iOS and Android only - the web build does not render the spoiler overlay, so these properties have no visible effect here. The source is shown for reference.</>} />

### Superscript-specific

Styles for superscript text (`^text^`). Requires [`md4cFlags={{ superscript: true }}`](/react-native/api-reference/enriched-markdown-text#superscript) to enable the parser.

| Property              | Type     | Default                                  | Description                                                      |
| --------------------- | -------- | ---------------------------------------- | ---------------------------------------------------------------- |
| `fontScale`           | `number` | `0.75` (iOS/macOS/web), `0.65` (Android) | Font size as a fraction of the surrounding text size             |
| `baselineOffsetScale` | `number` | `0.35`                                   | Vertical shift upward as a fraction of the surrounding text size |

<LivePreview src={SuperscriptSrc} />

### Subscript-specific

Styles for subscript text (`~text~`). Requires [`md4cFlags={{ subscript: true }}`](/react-native/api-reference/enriched-markdown-text#subscript) to enable the parser. Note: enabling subscript changes the behavior of single tildes - `~text~` becomes subscript instead of strikethrough.

| Property              | Type     | Default                                  | Description                                                        |
| --------------------- | -------- | ---------------------------------------- | ------------------------------------------------------------------ |
| `fontScale`           | `number` | `0.75` (iOS/macOS/web), `0.65` (Android) | Font size as a fraction of the surrounding text size               |
| `baselineOffsetScale` | `number` | `0.20`                                   | Vertical shift downward as a fraction of the surrounding text size |

<LivePreview src={SubscriptSrc} />

:::note
Android uses a slightly smaller default `fontScale` (`0.65`) compared to iOS (`0.75`) because Roboto has a larger x-height than San Francisco, making identically-scaled text appear visually larger on Android.
:::

## Editor styles (`EnrichedMarkdownTextInput`) {#editor-styles}

The editable [`EnrichedMarkdownTextInput`](/react-native/api-reference/enriched-markdown-text-input) takes its own `markdownStyle` of type `MarkdownTextInputStyle`. It is a **subset** of the renderer's `MarkdownStyle` documented above: the editor supports inline formatting, links, spoilers, and headings, so only those elements are styleable - there is no `paragraph`, `code`, `blockquote`, `table`, and so on. Every field is optional and falls back to a default that matches the renderer, so content looks the same while editing and once rendered.

The base text appearance (font size, family, color) comes from the input's [`style`](/react-native/api-reference/enriched-markdown-text-input#style) prop, not from `markdownStyle`.

| Property                  | Type                                 | Default            | Description                                                                                                                                      |
| ------------------------- | ------------------------------------ | ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| `strong.color`            | `string`                             | Input text color   | Bold text color                                                                                                                                  |
| `em.color`                | `string`                             | Input text color   | Italic text color                                                                                                                                |
| `link.color`              | `string`                             | `#2563EB`          | Link text color                                                                                                                                  |
| `link.underline`          | `boolean`                            | `true`             | Whether links are underlined                                                                                                                     |
| `link.backgroundColor`    | `string`                             | `transparent`      | Link background color                                                                                                                            |
| `linkVariants`            | `Record<string, LinkStyle>`          | none               | Per-URL-pattern style overrides. Each key is a regex tested against the link URL; see [Mentions - Link variants](/rich-text-formatting/mentions) |
| `spoiler.color`           | `string`                             | `#374151`          | Spoiler text color                                                                                                                               |
| `spoiler.backgroundColor` | `string`                             | `#E5E7EB`          | Spoiler background color                                                                                                                         |
| `h1`–`h6`                 | `{ fontSize?, fontWeight?, color? }` | Match the renderer | Per-level heading styling. Defaults match the renderer (sizes `30/24/20/18/16/14`, bold); omitted levels or fields fall back to those defaults   |
| `list.itemSpacing`        | `number`                             | `0`                | Vertical spacing (points) added above each list item (bullet and numbered alike) so items read as separate rows                                  |

## Try it yourself

The example below sets a custom `markdownStyle`. Switch to the Code tab and tweak the values to see how each property changes the rendered output.

<InteractiveExample src={FirstTextSrc} component={FirstText} />
