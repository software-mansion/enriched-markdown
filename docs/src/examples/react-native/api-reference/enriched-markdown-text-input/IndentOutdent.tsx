import { useRef } from 'react';
import { View, Button, StyleSheet } from 'react-native';
import {
  EnrichedMarkdownTextInput,
  type EnrichedMarkdownTextInputInstance,
} from 'react-native-enriched-markdown';

// indentList / outdentList change the nesting of the current list item.
// Put the cursor on an item, then indent or outdent it.
export default function App() {
  const ref = useRef<EnrichedMarkdownTextInputInstance>(null);

  return (
    <View style={styles.container}>
      <EnrichedMarkdownTextInput
        ref={ref}
        defaultValue={'- Fruit\n- Apple\n- Banana\n- Vegetables'}
        style={styles.input}
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
  input: { fontSize: 18, padding: 12, minHeight: 120, backgroundColor: '#eef0ff' },
  toolbar: { flexDirection: 'row', gap: 8 },
});
