import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

const markdown = 'Water is H~2~O and carbon dioxide is CO~2~.';

export default function App() {
  const isDark = useColorScheme() === 'dark';

  // Subscript (~text~) needs md4cFlags={{ subscript: true }}, which repurposes
  // single tildes from strikethrough. fontScale sizes it; baselineOffsetScale
  // drops it below the baseline.
  const markdownStyle = {
    ...defaultMarkdownStyle(isDark),
    subscript: {
      fontScale: 0.75,
      baselineOffsetScale: 0.2,
    },
  };

  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        markdown={markdown}
        markdownStyle={markdownStyle}
        md4cFlags={{ subscript: true }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
});
