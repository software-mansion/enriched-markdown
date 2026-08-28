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
        defaultValue={'Buy milk\nWalk the dog\nWrite docs'}
        onChangeState={setState}
        style={styles.input}
      />
      <Button
        title="Bulleted list"
        color={state?.unorderedList.isActive ? 'green' : 'gray'}
        onPress={() => ref.current?.toggleUnorderedList()}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 8 },
  input: { fontSize: 18, padding: 12, minHeight: 110, backgroundColor: '#eef0ff' },
});
