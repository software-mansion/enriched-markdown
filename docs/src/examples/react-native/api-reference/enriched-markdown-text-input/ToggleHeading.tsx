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

  const color = (level: number) =>
    state?.heading.level === level ? 'green' : 'gray';

  return (
    <View style={styles.container}>
      <EnrichedMarkdownTextInput
        ref={ref}
        defaultValue="Put the cursor on this line, then pick a heading level."
        onChangeState={setState}
        style={styles.input}
      />
      <View style={styles.toolbar}>
        <Button title="H1" color={color(1)} onPress={() => ref.current?.toggleHeading(1)} />
        <Button title="H2" color={color(2)} onPress={() => ref.current?.toggleHeading(2)} />
        <Button title="H3" color={color(3)} onPress={() => ref.current?.toggleHeading(3)} />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 8 },
  input: { fontSize: 18, padding: 12, minHeight: 80, backgroundColor: '#eef0ff' },
  toolbar: { flexDirection: 'row', gap: 8 },
});
