import { useRef, useState } from 'react';
import { View, Button, Text, StyleSheet, useColorScheme } from 'react-native';
import {
  EnrichedMarkdownTextInput,
  type EnrichedMarkdownTextInputInstance,
  type CaretRect,
} from 'react-native-enriched-markdown';
import { defaultInputColors, defaultInputMarkdownStyle } from './theme';

export default function App() {
  const isDark = useColorScheme() === 'dark';
  const ref = useRef<EnrichedMarkdownTextInputInstance>(null);
  const [rect, setRect] = useState<CaretRect | null>(null);

  return (
    <View style={styles.container}>
      <EnrichedMarkdownTextInput
        markdownStyle={defaultInputMarkdownStyle(isDark)}
        ref={ref}
        defaultValue="Move the caret, then query it."
        style={{ ...styles.input, ...defaultInputColors(isDark) }}
      />
      <Button
        title="Get caret rect"
        onPress={async () => setRect((await ref.current?.getCaretRect()) ?? null)}
      />
      {rect && (
        <Text style={{ color: defaultInputColors(isDark).color }}>
          x:{Math.round(rect.x)} y:{Math.round(rect.y)} h:{Math.round(rect.height)}
        </Text>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 8 },
  input: { fontSize: 18, padding: 12, minHeight: 96 },
});
