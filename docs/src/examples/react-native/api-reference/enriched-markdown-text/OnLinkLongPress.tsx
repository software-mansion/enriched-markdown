import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, Text, StyleSheet, useColorScheme } from 'react-native';
import { useState } from 'react';
import { defaultMarkdownStyle } from './theme';

// On web, long press maps to the contextmenu event - right-click the link.
const markdown = 'Long-press (or right-click) [this link](https://reactnative.dev).';

export default function App() {
  const isDark = useColorScheme() === 'dark';
  const [status, setStatus] = useState('No link long-pressed yet.');

  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        markdown={markdown}
        markdownStyle={defaultMarkdownStyle(isDark)}
        onLinkLongPress={({ url }) => setStatus(`Long-pressed: ${url}`)}
      />
      <Text style={styles.status}>{status}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
  status: { fontSize: 14, fontStyle: 'italic', color: '#8a90a6' },
});
