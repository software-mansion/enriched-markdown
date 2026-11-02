import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { useMemo } from 'react';
import { defaultMarkdownStyle } from './theme';

const markdown =
  'With `strikethrough` on, ~~double~~ and ~single~ tildes both strike, while the text stays in a single CommonMark view.';

export default function App() {
  const isDark = useColorScheme() === 'dark';
  const markdownStyle = useMemo(() => defaultMarkdownStyle(isDark), [isDark]);

  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        markdown={markdown}
        markdownStyle={markdownStyle}
        flavor="commonmark"
        // Only needed under commonmark - flavor="github" always enables it.
        md4cFlags={{ strikethrough: true }}
        numberOfLines={3}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
});
