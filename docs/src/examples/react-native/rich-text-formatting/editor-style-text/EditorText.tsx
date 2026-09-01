import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

// Simulates content authored in the editor: single newlines between lines and a
// run of blank lines. With both flags on and paragraph margins zeroed, it
// renders line-for-line. Try turning the flags off to see the CommonMark default.
const markdown = 'First line\nSecond line\n\n\n\nAfter three blank lines.';

export default function App() {
  const isDark = useColorScheme() === 'dark';
  const base = defaultMarkdownStyle(isDark);

  const markdownStyle = {
    ...base,
    paragraph: { ...base.paragraph, marginTop: 0, marginBottom: 0 },
  };

  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        markdown={markdown}
        markdownStyle={markdownStyle}
        md4cFlags={{ hardSoftBreaks: true, preserveBlankLines: true }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
});
