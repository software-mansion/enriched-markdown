import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

const markdown = `> A blockquote draws its left border, gap, and background.
>
> Great for callouts and pull quotes.`;

export default function App() {
  const isDark = useColorScheme() === 'dark';

  // borderWidth and gapWidth set the accent bar; backgroundColor tints the
  // whole quote. padding insets the text from the box edges and borderRadius
  // rounds the corners, turning the bar into a filled card. An amber callout
  // that holds up in both schemes.
  const markdownStyle = {
    ...defaultMarkdownStyle(isDark),
    blockquote: {
      color: isDark ? '#fde68a' : '#92400e',
      borderColor: isDark ? '#f59e0b' : '#d97706',
      backgroundColor: isDark ? '#3a2f14' : '#fef3c7',
      borderWidth: 5,
      gapWidth: 14,
      padding: 12,
      borderRadius: 10,
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
