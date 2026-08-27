import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

const markdown = `The **container** view wraps the whole rendered document.

Use \`containerStyle\` for padding, background, and corner radius.`;

export default function App() {
  const isDark = useColorScheme() === 'dark';
  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        markdown={markdown}
        markdownStyle={defaultMarkdownStyle(isDark)}
        containerStyle={{
          padding: 16,
          borderRadius: 12,
          backgroundColor: isDark ? '#25322d' : '#e6f4ee',
        }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
});
