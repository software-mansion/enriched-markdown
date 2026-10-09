import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, Text, StyleSheet, useColorScheme } from 'react-native';
import { useState, useMemo } from 'react';
import { defaultMarkdownStyle } from './theme';

const markdown =
  'Open [README.md](https://example.com/files/README.md) or ask [@gregory](user:gregory).';

export default function App() {
  const isDark = useColorScheme() === 'dark';
  const markdownStyle = useMemo(() => defaultMarkdownStyle(isDark), [isDark]);
  const [status, setStatus] = useState('Long-press a link.');

  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        markdown={markdown}
        markdownStyle={markdownStyle}
        // One entry per kind of link. Keys are URL patterns, like `linkVariants`.
        linkContextMenuItems={{
          '^https://example\\.com/files/': [
            {
              text: 'Copy path',
              icon: 'doc.on.doc',
              onPress: ({ url }) => setStatus(`Copied ${url}`),
            },
            {
              text: 'Delete',
              icon: 'trash',
              destructive: true,
              onPress: ({ url }) => setStatus(`Deleted ${url}`),
            },
          ],
          '^user:': [
            {
              text: 'Mention',
              icon: 'at',
              onPress: ({ url }) => setStatus(`Mentioning ${url}`),
            },
          ],
        }}
        // Android, macOS and iOS 16 ignore the menus and fall back to this.
        onLinkLongPress={({ url }) => setStatus(`Long-pressed ${url}`)}
      />
      <Text style={styles.status}>{status}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
  status: { fontSize: 14, fontStyle: 'italic', color: '#8a90a6' },
});
