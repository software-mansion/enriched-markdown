import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

const markdown =
  'Select part of this sentence to see the amber selection highlight.';

export default function App() {
  const isDark = useColorScheme() === 'dark';

  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        markdown={markdown}
        markdownStyle={defaultMarkdownStyle(isDark)}
        selectionColor="#f59e0b"
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
});
