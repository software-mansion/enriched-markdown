import { useRef, useState } from 'react';
import { View, Button, StyleSheet } from 'react-native';
import {
  EnrichedMarkdownTextInput,
  type EnrichedMarkdownTextInputInstance,
  type StyleState,
} from 'react-native-enriched-markdown';

export default function App() {
  const ref = useRef<EnrichedMarkdownTextInputInstance>(null);
  const [state, setState] = useState<StyleState | null>(null);

  return (
    <View style={styles.container}>
      <EnrichedMarkdownTextInput
        ref={ref}
        defaultValue="Select some text, then hide it behind a spoiler."
        onChangeState={setState}
        style={styles.input}
      />
      <Button
        title="Spoiler"
        color={state?.spoiler.isActive ? 'green' : 'gray'}
        onPress={() => ref.current?.toggleSpoiler()}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 8 },
  input: { fontSize: 18, padding: 12, minHeight: 80, backgroundColor: '#eef0ff' },
});
