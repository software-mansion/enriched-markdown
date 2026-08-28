import { EnrichedMarkdownTextInput } from 'react-native-enriched-markdown';

export default function App() {
  return (
    <EnrichedMarkdownTextInput
      autoCapitalize="words"
      placeholder="Each Word Is Capitalized"
    />
  );
}
