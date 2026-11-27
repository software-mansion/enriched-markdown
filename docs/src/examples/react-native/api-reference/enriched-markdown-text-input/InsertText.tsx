import { useRef } from 'react';
import { View, Button, StyleSheet, useColorScheme } from 'react-native';
import {
  EnrichedMarkdownTextInput,
  type EnrichedMarkdownTextInputInstance,
} from 'react-native-enriched-markdown';
import { defaultInputColors, defaultInputMarkdownStyle } from './theme';

// insertText parses its argument as Markdown and inserts it at the cursor.
export default function App() {
  const isDark = useColorScheme() === 'dark';
  const ref = useRef<EnrichedMarkdownTextInputInstance>(null);

  return (
    <View style={styles.container}>
      <EnrichedMarkdownTextInput
        markdownStyle={defaultInputMarkdownStyle(isDark)}
        ref={ref}
        defaultValue="Place the cursor here, then insert: "
        style={{ ...styles.input, ...defaultInputColors(isDark) }}
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
  input: { fontSize: 18, padding: 12, minHeight: 96 },
  toolbar: { flexDirection: 'row', gap: 8 },
});
