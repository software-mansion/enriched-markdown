import { EnrichedMarkdownTextInput } from 'react-native-enriched-markdown';

export default function App() {
  return (
    <EnrichedMarkdownTextInput
      placeholder="Type to log keys"
      onKeyPress={({ nativeEvent: { key } }) => {
        console.log('Pressed key:', key);
      }}
    />
  );
}
