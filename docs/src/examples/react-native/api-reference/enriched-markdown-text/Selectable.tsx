import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

const markdown =
  'With `selectable={false}` you cannot select or highlight this text. Try dragging across it.';

export default function App() {
  const isDark = useColorScheme() === 'dark';

  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        markdown={markdown}
        markdownStyle={defaultMarkdownStyle(isDark)}
        selectable={false}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
});
