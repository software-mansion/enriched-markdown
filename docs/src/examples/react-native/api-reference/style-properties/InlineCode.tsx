import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

const markdown = 'Call `useMemo()` to memoize the `markdownStyle` prop.';

export default function App() {
  const isDark = useColorScheme() === 'dark';

  // Inline code renders as a chip: color, backgroundColor, and borderColor tint
  // it; fontSize overrides the inherited block size when set.
  const markdownStyle = {
    ...defaultMarkdownStyle(isDark),
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
