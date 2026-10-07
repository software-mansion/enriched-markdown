import { useState } from 'react';
import { Text, Pressable, StyleSheet } from 'react-native';
import { EnrichedMarkdownTextInput } from 'react-native-enriched-markdown';

export default function App() {
  const [log, setLog] = useState('Tap the input, or the card around it');

  return (
    <Pressable
      style={styles.card}
      onPress={() => setLog('Card pressed - the tap missed the input')}
    >
      <EnrichedMarkdownTextInput
        placeholder="Tap me"
        hitSlop={12}
        onPressIn={() => setLog('Input press in')}
        onPressOut={() => setLog('Input press out')}
        onPress={() => setLog('Input pressed - the card stayed quiet')}
        style={styles.input}
      />
      <Text>{log}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  card: { gap: 8, padding: 16, backgroundColor: '#f6f6f8' },
  input: {
    fontSize: 18,
    padding: 12,
    minHeight: 80,
    backgroundColor: '#eef0ff',
  },
});
