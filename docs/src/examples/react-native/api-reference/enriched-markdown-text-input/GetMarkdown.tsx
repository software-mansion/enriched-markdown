import { useRef, useState } from 'react';
import { View, Button, Text, StyleSheet, useColorScheme } from 'react-native';
import {
  EnrichedMarkdownTextInput,
  type EnrichedMarkdownTextInputInstance,
} from 'react-native-enriched-markdown';
import { defaultInputColors, defaultInputMarkdownStyle } from './theme';

export default function App() {
  const isDark = useColorScheme() === 'dark';
  const ref = useRef<EnrichedMarkdownTextInputInstance>(null);
  const [markdown, setMarkdown] = useState('');

  const showMarkdown = async () => {
    setMarkdown((await ref.current?.getMarkdown()) ?? '');
  };

  return (
    <View style={styles.container}>
      <EnrichedMarkdownTextInput
        markdownStyle={defaultInputMarkdownStyle(isDark)}
        ref={ref}
        defaultValue="Edit me, then read the **Markdown** back."
        style={{ ...styles.input, ...defaultInputColors(isDark) }}
      />
      <Button title="Get Markdown" onPress={showMarkdown} />
      {markdown !== '' && <Text style={{ ...styles.output, color: defaultInputColors(isDark).color }}>{markdown}</Text>}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 8 },
  input: { fontSize: 18, padding: 12, minHeight: 96 },
  output: { fontFamily: 'monospace' },
});
