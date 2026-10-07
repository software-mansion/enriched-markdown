import { EnrichedMarkdownTextInput } from 'react-native-enriched-markdown';

export default function App() {
  return (
    <EnrichedMarkdownTextInput
      placeholder="Type '## ' or '- ' at the start of a line"
      // `true` would enable all three; this enables only headings and bullets,
      // leaving a typed "1. " as literal text.
      markdownShortcuts={{ heading: true, unorderedList: true }}
    />
  );
}
