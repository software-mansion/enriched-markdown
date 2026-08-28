import { useRef, useState } from 'react';
import { View, Text, Button, StyleSheet } from 'react-native';
import {
  EnrichedMarkdownTextInput,
  type EnrichedMarkdownTextInputInstance,
} from 'react-native-enriched-markdown';

export default function App() {
  const ref = useRef<EnrichedMarkdownTextInputInstance>(null);
  const [focused, setFocused] = useState(false);

  return (
    <View style={styles.container}>
      <EnrichedMarkdownTextInput
        ref={ref}
        placeholder="Focus me"
        onFocus={() => setFocused(true)}
        onBlur={() => setFocused(false)}
        style={styles.input}
      />
      <Text>{focused ? 'Focused' : 'Not focused'}</Text>
      <View style={styles.toolbar}>
        <Button title="Focus" onPress={() => ref.current?.focus()} />
        <Button title="Blur" onPress={() => ref.current?.blur()} />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 8 },
  input: { fontSize: 18, padding: 12, minHeight: 80, backgroundColor: '#eef0ff' },
  toolbar: { flexDirection: 'row', gap: 8 },
});
