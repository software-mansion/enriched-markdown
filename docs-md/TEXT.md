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

### Task Lists

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

To render checkboxes that display their markdown state but cannot be toggled by the user, set [`enableTaskListItemToggle`](API_REFERENCE.md#enabletasklistitemtoggle) to `false`. The tap becomes fully inert — no visual toggle and no `onTaskListItemPress` — while text selection and links in the same row keep working.

```tsx
<EnrichedMarkdownText
  flavor="github"
  markdown={content}
  enableTaskListItemToggle={false}
/>
```

### Link Handling

Links in Markdown are interactive and can be handled with the `onLinkPress` and `onLinkLongPress` callbacks:

- **`onLinkPress`**: Fired when a link is tapped. Use this to open URLs or handle link navigation.
- **`onLinkLongPress`**: Fired when a link is long-pressed. On iOS, providing this callback automatically disables the system link preview so your handler can fire instead.

See the [API Reference](API_REFERENCE.md#onlinkpress) for detailed examples and usage.

## Supported Markdown Elements

`react-native-enriched-markdown` supports a comprehensive set of Markdown elements. See [Element Structure](ELEMENTS_STRUCTURE.md) for a detailed overview of all supported elements, their syntax, block vs inline categorization, nesting behavior, and how elements inherit typography from their parent blocks.

## Copy Options

When text is selected, `react-native-enriched-markdown` provides enhanced copy functionality through the context menu. See [Copy Options](COPY_OPTIONS.md) for details on smart copy, copy as Markdown, and copy image URL features.

## Accessibility

`react-native-enriched-markdown` provides comprehensive accessibility support for screen readers on both platforms. See [Accessibility](ACCESSIBILITY.md) for detailed information about VoiceOver and TalkBack support, custom rotors, semantic traits, and best practices.

## RTL Support

`react-native-enriched-markdown` fully supports right-to-left (RTL) languages such as Arabic, Hebrew, and Persian. See [RTL Support](RTL.md) for platform-specific setup instructions and how each element behaves in RTL contexts.

## Customizing Styles

`react-native-enriched-markdown` allows customizing styles of all Markdown elements using the `markdownStyle` prop. See the [Style Properties Reference](STYLES.md) for a detailed overview of all available style properties.

### Dark Mode

The library uses light-mode defaults. To support dark mode, pass a dark `markdownStyle` object — your values always take priority over the defaults. See the [Dark Mode](STYLES.md#dark-mode) section in the Style Properties Reference for a ready-to-use example with `useColorScheme()`.
