import { EnrichedMarkdownText } from 'react-native-enriched-markdown';

const markdown = 'Select some of this **text** and copy it.';

export default function App() {
  return (
    <EnrichedMarkdownText
      markdown={markdown}
      // Fires for the selection menu's Copy, Copy as Markdown and Copy Image
      // URL items, the keyboard shortcut and TalkBack's copy action.
      onSelectionCopy={({ text, format, selection }) => {
        console.log(
          `Copied ${format} (${selection.start}-${selection.end}):`,
          text,
        );
      }}
    />
  );
}
