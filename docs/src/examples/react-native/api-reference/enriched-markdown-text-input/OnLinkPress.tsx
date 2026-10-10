import { useState } from 'react';
import { Text, StyleSheet } from 'react-native';
import { EnrichedMarkdownTextInput } from 'react-native-enriched-markdown';

export default function App() {
  const [status, setStatus] = useState(
    'Blur the input, then tap the link below',
  );

  return (
    <>
      <EnrichedMarkdownTextInput
        defaultValue="Tap [React Native](https://reactnative.dev) while this input is not focused."
        onLinkPress={({ url }) => setStatus(`Pressed: ${url}`)}
        style={styles.input}
      />
      <Text style={styles.status}>{status}</Text>
    </>
  );
}

const styles = StyleSheet.create({
  input: {
    fontSize: 18,
    padding: 12,
    minHeight: 80,
    backgroundColor: '#eef0ff',
  },
  status: { fontSize: 14, fontStyle: 'italic', color: '#8a90a6' },
});
