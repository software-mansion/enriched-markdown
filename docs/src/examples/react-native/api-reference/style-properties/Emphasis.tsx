import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

const markdown = 'Add a little *emphasis* to the right words.';

export default function App() {
  const isDark = useColorScheme() === 'dark';

  // Emphasis adds the italic trait to the inherited block font and takes its
  // own color. Set fontFamily to swap the face; fontStyle: 'normal' uses it as-is.
  const markdownStyle = {
    ...defaultMarkdownStyle(isDark),
    em: {
      color: isDark ? '#c4b5fd' : '#7c3aed',
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
