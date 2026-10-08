import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { useMemo } from 'react';
import { defaultMarkdownStyle } from './theme';

const markdown = 'With `superscript` on, write E = mc^2^ or the n^th^ term.';

export default function App() {
  const isDark = useColorScheme() === 'dark';
  const markdownStyle = useMemo(() => defaultMarkdownStyle(isDark), [isDark]);

  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        markdown={markdown}
        markdownStyle={markdownStyle}
        md4cFlags={{ superscript: true }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
});
