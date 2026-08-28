import { useRef } from 'react';
import { View, Button, StyleSheet } from 'react-native';
import {
  EnrichedMarkdownTextInput,
  type EnrichedMarkdownTextInputInstance,
} from 'react-native-enriched-markdown';

export default function App() {
  const ref = useRef<EnrichedMarkdownTextInputInstance>(null);

  return (
    <View style={styles.container}>
      <EnrichedMarkdownTextInput
        ref={ref}
        defaultValue="This whole document copies to the clipboard, formatting included."
        style={styles.input}
      />
      <Button title="Copy all" onPress={() => ref.current?.copyToClipboard()} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 8 },
  input: { fontSize: 18, padding: 12, minHeight: 96, backgroundColor: '#eef0ff' },
});
