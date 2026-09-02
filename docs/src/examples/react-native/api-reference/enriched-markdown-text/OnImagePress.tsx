import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, Text, StyleSheet, useColorScheme } from 'react-native';
import { useState } from 'react';
import { defaultMarkdownStyle } from './theme';

const markdown =
  'Tap the image to open it:\n\n![A scenic mountain](https://picsum.photos/id/29/400/200)';

export default function App() {
  const isDark = useColorScheme() === 'dark';
  const [status, setStatus] = useState('No image pressed yet.');

  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        markdown={markdown}
        markdownStyle={defaultMarkdownStyle(isDark)}
        onImagePress={({ url, altText }) =>
          setStatus(`Pressed: ${altText || url}`)
        }
      />
      <Text style={styles.status}>{status}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
  status: { fontSize: 14, fontStyle: 'italic', color: '#8a90a6' },
});
