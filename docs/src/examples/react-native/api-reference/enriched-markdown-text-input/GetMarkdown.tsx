import { useRef } from 'react';
import { View, Button, Alert, StyleSheet } from 'react-native';
import {
  EnrichedMarkdownTextInput,
  type EnrichedMarkdownTextInputInstance,
} from 'react-native-enriched-markdown';

export default function App() {
  const ref = useRef<EnrichedMarkdownTextInputInstance>(null);

  const showMarkdown = async () => {
    const markdown = await ref.current?.getMarkdown();
    if (markdown) Alert.alert('Markdown', markdown);
  };

  return (
    <View style={styles.container}>
      <EnrichedMarkdownTextInput
        ref={ref}
        defaultValue="Edit me, then read the **Markdown** back."
        style={styles.input}
      />
      <Button title="Get Markdown" onPress={showMarkdown} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 8 },
  input: { fontSize: 18, padding: 12, minHeight: 96, backgroundColor: '#eef0ff' },
});
