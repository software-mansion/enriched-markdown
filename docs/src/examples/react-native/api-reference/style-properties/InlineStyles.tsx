import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

const markdown =
  'Mix **bold**, *italic*, a [link](https://docs.swmansion.com), and `inline code` in one line.';

export default function App() {
  const isDark = useColorScheme() === 'dark';

  // Inline elements inherit the block typography, then layer their own color
  // (and, for links, an underline) on top.
  const markdownStyle = {
    ...defaultMarkdownStyle(isDark),
    strong: { color: isDark ? '#fca5a5' : '#dc2626' },
    em: { color: isDark ? '#c4b5fd' : '#7c3aed' },
    link: { color: isDark ? '#7dd3fc' : '#0284c7', underline: true },
    code: {
      color: isDark ? '#fbcfe8' : '#be185d',
      backgroundColor: isDark ? '#3b1f2e' : '#fce7f3',
      borderColor: isDark ? '#7a3350' : '#f9a8d4',
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
