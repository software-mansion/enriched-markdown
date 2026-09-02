import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

const markdown = `- عنصر أول
- عنصر ثانٍ

> اقتباس لإظهار الحد على الجانب الأيمن.`;

export default function App() {
  const isDark = useColorScheme() === 'dark';

  // dir="rtl" flips list indentation, blockquote borders, and text alignment
  // via CSS logical properties on web.
  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        markdown={markdown}
        markdownStyle={defaultMarkdownStyle(isDark)}
        dir="rtl"
      />
    </View>
  );
}

const styles = StyleSheet.create({
  // Extra vertical padding: the RTL content right-aligns, so without it the top
  // line would sit under the floating Preview/Code/copy controls and the last
  // line under the bottom-right reset button.
  container: { gap: 12, paddingTop: 28, paddingBottom: 28 },
});
