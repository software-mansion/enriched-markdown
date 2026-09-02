import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

const markdown = `- [x] This reflects the markdown
- [ ] ...but tapping does nothing
- [x] The checkboxes are read-only
`;

export default function App() {
  const isDark = useColorScheme() === 'dark';

  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        markdown={markdown}
        flavor="github"
        markdownStyle={defaultMarkdownStyle(isDark)}
        // Checkboxes render their markdown state but the tap is fully inert.
        enableTaskListItemToggle={false}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
});
