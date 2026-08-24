---
sidebar_label: EnrichedMarkdownText
sidebar_position: 3
---

# EnrichedMarkdownText

`EnrichedMarkdownText` renders Markdown content as fully native text — no WebView required.

## Usage

### CommonMark (default)

```tsx
import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { Linking } from 'react-native';

const markdown = `
# Welcome to Markdown!

This is a paragraph with **bold**, *italic*, and [links](https://reactnative.dev).

- List item one
- List item two
  - Nested item
`;

export default function App() {
  return (
    <EnrichedMarkdownText
      markdown={markdown}
      onLinkPress={({ url }) => Linking.openURL(url)}
    />
  );
}
```

### GFM (tables)

Set `flavor="github"` to enable GitHub Flavored Markdown features like tables and task lists:

```tsx
<EnrichedMarkdownText
  flavor="github"
  markdown={markdown}
  onLinkPress={({ url }) => Linking.openURL(url)}
  markdownStyle={{
    table: {
      fontSize: 14,
      borderColor: '#E5E7EB',
      borderRadius: 8,
      headerBackgroundColor: '#F3F4F6',
      headerFontFamily: 'System-Bold',
      cellPaddingHorizontal: 12,
      cellPaddingVertical: 8,
    },
  }}
/>
```

Tables support column alignment, rich text in cells (bold, italic, code, links), horizontal scrolling, header styling, alternating row colors, and a long-press context menu with "Copy" and "Copy as Markdown".

### Task lists

Task lists with interactive checkboxes are available when `flavor="github"` is set. Handle checkbox taps with `onTaskListItemPress`:

```tsx
<EnrichedMarkdownText
  flavor="github"
  markdown={`
- [x] Completed task
- [ ] Incomplete task
- [x] Another completed task
  `}
  onTaskListItemPress={({ index, checked, text }) => {
    console.log(
      `Task ${index}: ${checked ? 'checked' : 'unchecked'} - ${text}`
    );
    // Update your state or data model here
  }}
/>
```

### Link handling

Links in Markdown are interactive and can be handled with the `onLinkPress` and `onLinkLongPress` callbacks:

- **`onLinkPress`** — fired when a link is tapped. Use this to open URLs or handle link navigation.
- **`onLinkLongPress`** — fired when a link is long-pressed. On iOS, providing this callback automatically disables the system link preview so your handler can fire instead.

## Supported Markdown elements

`EnrichedMarkdownText` supports a comprehensive set of Markdown elements. See [Element structure](/react-native/element-structure) for a detailed overview of all supported elements, their syntax, block vs. inline categorization, nesting behavior, and how elements inherit typography from their parent blocks.

## Copy options

When text is selected, the component provides enhanced copy functionality through the context menu. See [Copy options](/misc/copy-options) for details on smart copy, copy as Markdown, and copy image URL features.

## Accessibility

`EnrichedMarkdownText` provides comprehensive accessibility support for screen readers on both platforms. See [Accessibility](/misc/accessibility) for detailed information about VoiceOver and TalkBack support, custom rotors, semantic traits, and best practices.

## RTL support

The component fully supports right-to-left (RTL) languages such as Arabic, Hebrew, and Persian. See [RTL support](/misc/rtl) for platform-specific setup instructions and how each element behaves in RTL contexts.

## Customizing styles

You can customize the styles of all Markdown elements using the `markdownStyle` prop. See the [Style properties reference](/react-native/style-properties) for a detailed overview of all available style properties.

### Dark mode

The library uses light-mode defaults. To support dark mode, pass a dark `markdownStyle` object — your values always take priority over the defaults. See the [Dark mode](/react-native/style-properties#dark-mode) section in the Style properties reference for a ready-to-use example with `useColorScheme()`.
