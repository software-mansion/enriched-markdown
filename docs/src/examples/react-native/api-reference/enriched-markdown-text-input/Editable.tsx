import { EnrichedMarkdownTextInput } from 'react-native-enriched-markdown';

export default function App() {
  return (
    <EnrichedMarkdownTextInput
      editable={false}
      defaultValue="This content is **selectable** but cannot be edited."
    />
  );
}
