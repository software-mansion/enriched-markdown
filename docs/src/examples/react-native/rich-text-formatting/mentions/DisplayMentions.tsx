import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, Text, StyleSheet, useColorScheme, Linking } from 'react-native';
import { useMemo, useState } from 'react';
import { defaultMarkdownStyle } from './theme';

// Mentions are just links with a custom URL scheme. Style each scheme with
// linkVariants - edit the colors below to see them update.
const markdown =
  'Hey [@Alice](user://alice), check out [#general](channel://general) or read the [docs](https://docs.swmansion.com).';

export default function App() {
  const isDark = useColorScheme() === 'dark';
  const [routed, setRouted] = useState('Tap a mention or a link.');

  const markdownStyle = useMemo(() => {
    const base = defaultMarkdownStyle(isDark);

    return {
      ...base,
      linkVariants: {
        '^user:': { color: '#1264A3', underline: false },
        '^channel:': { color: '#0f8a5f', underline: false },
      },
    };
  }, [isDark]);

  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        markdown={markdown}
        markdownStyle={markdownStyle}
        // A mention tap is a link tap - route it by scheme. Only ordinary
        // links are handed to the OS; the custom schemes stay in the app.
        onLinkPress={({ url }) => {
          if (url.startsWith('user://')) {
            setRouted(`Open profile: ${url.slice('user://'.length)}`);
          } else if (url.startsWith('channel://')) {
            setRouted(`Open channel: ${url.slice('channel://'.length)}`);
          } else {
            Linking.openURL(url);
          }
        }}
      />
      <Text style={isDark ? styles.statusDark : styles.status}>{routed}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
  status: { fontSize: 13, color: '#6b7280' },
  statusDark: { fontSize: 13, color: '#9ca3af' },
});
