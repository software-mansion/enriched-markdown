import { useRef, useState } from 'react';
import { View, Button, Text, StyleSheet } from 'react-native';
import {
  EnrichedMarkdownTextInput,
  type EnrichedMarkdownTextInputInstance,
  type CaretRect,
} from 'react-native-enriched-markdown';

export default function App() {
  const ref = useRef<EnrichedMarkdownTextInputInstance>(null);
  const [rect, setRect] = useState<CaretRect | null>(null);

  return (
    <View style={styles.container}>
      <EnrichedMarkdownTextInput
        ref={ref}
        defaultValue="Move the caret, then query it."
        style={styles.input}
      />
      <Button
        title="Get caret rect"
        onPress={async () => setRect((await ref.current?.getCaretRect()) ?? null)}
      />
      {rect && (
        <Text>
          x:{Math.round(rect.x)} y:{Math.round(rect.y)} h:{Math.round(rect.height)}
        </Text>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 8 },
  input: { fontSize: 18, padding: 12, minHeight: 96, backgroundColor: '#eef0ff' },
});
