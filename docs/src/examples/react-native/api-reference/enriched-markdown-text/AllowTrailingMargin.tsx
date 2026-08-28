import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

const markdown = `First paragraph.

Last paragraph - its bottom margin is kept because \`allowTrailingMargin\` is on.`;

export default function App() {
  const isDark = useColorScheme() === 'dark';
  const base = defaultMarkdownStyle(isDark);

  // Give paragraphs a bottom margin so the preserved trailing margin is
  // visible. Spread the base paragraph style so only marginBottom changes.
  const markdownStyle = {
    ...base,
    paragraph: { ...base.paragraph, marginBottom: 16 },
  };

  return (
    <View style={styles.container}>
      <View style={[styles.box, { borderColor: isDark ? '#4a5375' : '#c7cde0' }]}>
        <EnrichedMarkdownText
          markdown={markdown}
          markdownStyle={markdownStyle}
          allowTrailingMargin
        />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
  box: { borderWidth: 1, borderRadius: 8, paddingHorizontal: 12, paddingTop: 12 },
});
