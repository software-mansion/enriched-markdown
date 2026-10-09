import { useRef } from 'react';
import { View, Button, StyleSheet } from 'react-native';
import {
  EnrichedMarkdownTextInput,
  type EnrichedMarkdownTextInputInstance,
} from 'react-native-enriched-markdown';

// insertText parses its argument as Markdown and inserts it at the cursor.
export default function App() {
  const ref = useRef<EnrichedMarkdownTextInputInstance>(null);

  return (
    <View style={styles.container}>
      <EnrichedMarkdownTextInput
        ref={ref}
        defaultValue="Place the cursor here, then insert: "
        style={styles.input}
      />
      <View style={styles.toolbar}>
        <Button title="Insert bold" onPress={() => ref.current?.insertText('**bold**')} />
        <Button title="Insert bullet" onPress={() => ref.current?.insertText('\n- new item\n')} />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 8 },
  input: { fontSize: 18, padding: 12, minHeight: 96, backgroundColor: '#eef0ff' },
  toolbar: { flexDirection: 'row', gap: 8 },
});
