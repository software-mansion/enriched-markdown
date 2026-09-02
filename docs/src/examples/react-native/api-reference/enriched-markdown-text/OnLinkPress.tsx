import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, Text, StyleSheet, useColorScheme } from 'react-native';
import { useState } from 'react';
import { defaultMarkdownStyle } from './theme';

const markdown =
  'Tap [React Native](https://reactnative.dev) or [Software Mansion](https://swmansion.com).';

export default function App() {
  const isDark = useColorScheme() === 'dark';
  const [status, setStatus] = useState('No link pressed yet.');

  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        markdown={markdown}
        markdownStyle={defaultMarkdownStyle(isDark)}
        onLinkPress={({ url }) => setStatus(`Pressed: ${url}`)}
      />
      <Text style={styles.status}>{status}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
  status: { fontSize: 14, fontStyle: 'italic', color: '#8a90a6' },
});
