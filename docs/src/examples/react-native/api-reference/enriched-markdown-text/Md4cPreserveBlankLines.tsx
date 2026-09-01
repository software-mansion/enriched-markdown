import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

// Runs of blank lines. With preserveBlankLines off they collapse into a single
// paragraph break; with it on each blank line renders as one empty line.
// Paragraph margins are zeroed so the spacing comes purely from the blank lines.
const markdown = 'First paragraph\n\n\n\nSecond paragraph';

export default function App() {
  const isDark = useColorScheme() === 'dark';
  const base = defaultMarkdownStyle(isDark);
  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        markdown={markdown}
        markdownStyle={{
          ...base,
          paragraph: { ...base.paragraph, marginTop: 0, marginBottom: 0 },
        }}
        md4cFlags={{ preserveBlankLines: true }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
});
