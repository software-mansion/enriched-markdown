import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

const markdown =
  'With `subscript` on, write H~2~O and CO~2~. On the other hand ~~this~~ is allways strikethrough';

export default function App() {
  const isDark = useColorScheme() === 'dark';
  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        markdown={markdown}
        markdownStyle={defaultMarkdownStyle(isDark)}
        md4cFlags={{ subscript: true }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
});
