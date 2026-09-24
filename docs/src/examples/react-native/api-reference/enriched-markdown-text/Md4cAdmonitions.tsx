import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { useMemo } from 'react';
import { defaultMarkdownStyle } from './theme';

const markdown = `> [!NOTE]
> Useful information the reader should know.

> [!WARNING]
> Urgent info that needs immediate attention.

> A plain blockquote is untouched.`;

export default function App() {
  const isDark = useColorScheme() === 'dark';
  const markdownStyle = useMemo(() => defaultMarkdownStyle(isDark), [isDark]);

  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        flavor="github"
        markdown={markdown}
        markdownStyle={markdownStyle}
        // On by default - set it to false to render `> [!NOTE]` blockquotes as
        // plain blockquotes. Only takes effect with flavor="github".
        md4cFlags={{ admonitions: true }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
});
