import { EnrichedMarkdownTextInput } from 'react-native-enriched-markdown';

export default function App() {
  return (
    <EnrichedMarkdownTextInput
      selectionColor="#FDE68A"
      defaultValue="Select this text to see the highlight color."
    />
  );
}
