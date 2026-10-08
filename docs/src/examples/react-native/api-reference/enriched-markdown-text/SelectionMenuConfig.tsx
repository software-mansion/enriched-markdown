import { EnrichedMarkdownText } from 'react-native-enriched-markdown';

const markdown = 'Select this text to see the customized selection menu.';

export default function App() {
  return (
    <EnrichedMarkdownText
      markdown={markdown}
      selectionMenuConfig={{
        // Hide the built-in "Copy as Markdown" action...
        copyAsMarkdown: { enabled: false },
        // ...and relabel the system Copy item (it can't be hidden).
        copy: { label: 'Copy text' },
      }}
    />
  );
}
