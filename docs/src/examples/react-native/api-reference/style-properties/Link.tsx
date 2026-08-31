import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

const markdown =
  'Visit the [documentation](https://docs.swmansion.com) for the full guide.';

export default function App() {
  const isDark = useColorScheme() === 'dark';

  // Links take their own color, an optional underline, and a backgroundColor
  // chip; fontFamily overrides the inherited block font when set.
  const markdownStyle = {
    ...defaultMarkdownStyle(isDark),
    link: {
      color: isDark ? '#7dd3fc' : '#0284c7',
      underline: true,
      backgroundColor: isDark ? '#0c2a3a' : '#e0f2fe',
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
