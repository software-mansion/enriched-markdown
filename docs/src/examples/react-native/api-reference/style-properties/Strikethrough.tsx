import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

const markdown = 'Cross out ~~the old price~~ and show the new one.';

export default function App() {
  const isDark = useColorScheme() === 'dark';

  // Strikethrough (~~text~~) only exposes the line color. The color applies on
  // iOS and web; Android draws the strike in the text color.
  const markdownStyle = {
    ...defaultMarkdownStyle(isDark),
    strikethrough: {
      color: isDark ? '#f87171' : '#dc2626',
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
