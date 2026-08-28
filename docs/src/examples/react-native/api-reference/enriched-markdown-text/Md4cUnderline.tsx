import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

const markdown = 'With `underline` on, _this_ is underlined and *this* stays italic.';

export default function App() {
  const isDark = useColorScheme() === 'dark';
  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        markdown={markdown}
        markdownStyle={defaultMarkdownStyle(isDark)}
        md4cFlags={{ underline: true }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
});
