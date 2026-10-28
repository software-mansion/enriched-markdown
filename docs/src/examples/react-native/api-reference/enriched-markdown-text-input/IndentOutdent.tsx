import { useRef } from 'react';
import { View, Button, StyleSheet, useColorScheme } from 'react-native';
import {
  EnrichedMarkdownTextInput,
  type EnrichedMarkdownTextInputInstance,
} from 'react-native-enriched-markdown';
import { defaultInputColors, defaultInputMarkdownStyle } from './theme';

// indentList / outdentList change the nesting of the current list item.
// Put the cursor on an item, then indent or outdent it.
export default function App() {
  const isDark = useColorScheme() === 'dark';
  const ref = useRef<EnrichedMarkdownTextInputInstance>(null);

  return (
    <View style={styles.container}>
      <EnrichedMarkdownTextInput
        markdownStyle={defaultInputMarkdownStyle(isDark)}
        ref={ref}
        defaultValue={'- Fruit\n- Apple\n- Banana\n- Vegetables'}
        style={{ ...styles.input, ...defaultInputColors(isDark) }}
      />
      <View style={styles.toolbar}>
        <Button title="Indent" onPress={() => ref.current?.indentList()} />
        <Button title="Outdent" onPress={() => ref.current?.outdentList()} />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 8 },
  input: { fontSize: 18, padding: 12, minHeight: 120 },
  toolbar: { flexDirection: 'row', gap: 8 },
});
