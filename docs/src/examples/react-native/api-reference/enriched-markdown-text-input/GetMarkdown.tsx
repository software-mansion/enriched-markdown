import { useRef, useState } from 'react';
import { View, Button, Text, StyleSheet } from 'react-native';
import {
  EnrichedMarkdownTextInput,
  type EnrichedMarkdownTextInputInstance,
} from 'react-native-enriched-markdown';

export default function App() {
  const ref = useRef<EnrichedMarkdownTextInputInstance>(null);
  const [markdown, setMarkdown] = useState('');

  const showMarkdown = async () => {
    setMarkdown((await ref.current?.getMarkdown()) ?? '');
  };

  return (
    <View style={styles.container}>
      <EnrichedMarkdownTextInput
        ref={ref}
        defaultValue="Edit me, then read the **Markdown** back."
        style={styles.input}
      />
      <Button title="Get Markdown" onPress={showMarkdown} />
      {markdown !== '' && <Text style={styles.output}>{markdown}</Text>}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 8 },
  input: { fontSize: 18, padding: 12, minHeight: 96, backgroundColor: '#eef0ff' },
  output: { fontFamily: 'monospace' },
});
