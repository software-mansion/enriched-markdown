import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

const markdown = 'With `highlight` on, ==this text is highlighted== like a marker.';

export default function App() {
  const isDark = useColorScheme() === 'dark';
  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        markdown={markdown}
        markdownStyle={defaultMarkdownStyle(isDark)}
        md4cFlags={{ highlight: true }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
});
