import { useRef, useState } from 'react';
import { View, Button, Text, StyleSheet } from 'react-native';
import {
  EnrichedMarkdownTextInput,
  type EnrichedMarkdownTextInputInstance,
} from 'react-native-enriched-markdown';

// startMention inserts the indicator and opens a mention flow from a button,
// instead of waiting for the user to type "@".
export default function App() {
  const ref = useRef<EnrichedMarkdownTextInputInstance>(null);
  const [active, setActive] = useState(false);

  return (
    <View style={styles.container}>
      <EnrichedMarkdownTextInput
        ref={ref}
        mentionIndicators={['@']}
        placeholder="Tap the button to start a mention"
        onStartMention={() => setActive(true)}
        onEndMention={() => setActive(false)}
        style={styles.input}
      />
      <Button title="Mention someone" onPress={() => ref.current?.startMention('@')} />
      <Text>{active ? 'Mention flow active' : 'Idle'}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 8 },
  input: { fontSize: 18, padding: 12, minHeight: 96, backgroundColor: '#eef0ff' },
});
