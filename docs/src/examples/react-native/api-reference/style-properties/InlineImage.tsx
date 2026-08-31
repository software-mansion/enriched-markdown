import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

const src =
  'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI0OCIgaGVpZ2h0PSI0OCI+PGNpcmNsZSBjeD0iMjQiIGN5PSIyNCIgcj0iMjIiIGZpbGw9IiM3YzNhZWQiLz48L3N2Zz4=';

const markdown = `An inline icon ![icon](${src}) sits in the text flow.`;

export default function App() {
  const isDark = useColorScheme() === 'dark';

  // An inline image sits within a line of text. Its only style is size, which
  // renders it as a square scaled to the surrounding text.
  const markdownStyle = {
    ...defaultMarkdownStyle(isDark),
    inlineImage: {
      size: 24,
    },
  };

  return (
    <View style={styles.container}>
      <EnrichedMarkdownText markdown={markdown} markdownStyle={markdownStyle} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
});
