import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

const markdown = 'Make it **bold and clear** when it matters.';

export default function App() {
  const isDark = useColorScheme() === 'dark';

  // Strong adds the bold trait to the inherited block font and takes its own
  // color. Set fontFamily to swap the face; fontWeight: 'normal' uses it as-is.
  const markdownStyle = {
    ...defaultMarkdownStyle(isDark),
    strong: {
      color: isDark ? '#fca5a5' : '#dc2626',
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
