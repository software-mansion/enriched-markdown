import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

// Mentions are just links with a custom URL scheme. Style each scheme with
// linkVariants - edit the colors below to see them update.
const markdown =
  'Hey [@Alice](user://alice), check out [#general](channel://general).';

export default function App() {
  const isDark = useColorScheme() === 'dark';
  const base = defaultMarkdownStyle(isDark);

  const markdownStyle = {
    ...base,
    linkVariants: {
      '^user:': { color: '#1264A3', underline: false },
      '^channel:': { color: '#0f8a5f', underline: false },
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
