import { EnrichedMarkdownTextInput } from 'react-native-enriched-markdown';

export default function App() {
  return (
    <EnrichedMarkdownTextInput
      defaultValue="Select text, open Format, and note the trimmed list."
      formatMenuConfig={{
        // Keep only Bold, Italic, and Link in the Format submenu.
        underline: { enabled: false },
        strikethrough: { enabled: false },
        spoiler: { enabled: false },
      }}
    />
  );
}
