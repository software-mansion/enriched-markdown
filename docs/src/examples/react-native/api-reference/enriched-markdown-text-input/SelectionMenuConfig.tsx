import { EnrichedMarkdownTextInput } from 'react-native-enriched-markdown';

export default function App() {
  return (
    <EnrichedMarkdownTextInput
      defaultValue="Select text to see the tailored menu."
      selectionMenuConfig={{
        // Hide the Copy as Markdown action and relabel the Format submenu.
        copyAsMarkdown: { enabled: false },
        format: { label: 'Formatting' },
      }}
    />
  );
}
