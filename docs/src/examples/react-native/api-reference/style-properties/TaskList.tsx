import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, StyleSheet, useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

const markdown = `- [x] Ship the feature
- [x] Write the docs
- [ ] Add dark mode
- [ ] Celebrate`;

export default function App() {
  const isDark = useColorScheme() === 'dark';

  // Task lists need flavor="github". checkedColor fills the box, and checked
  // rows can dim and strike through.
  const markdownStyle = {
    ...defaultMarkdownStyle(isDark),
    taskList: {
      checkedColor: isDark ? '#57b495' : '#3f9e82',
      checkmarkColor: '#ffffff',
      borderColor: isDark ? '#57b495' : '#3f9e82',
      checkedTextColor: isDark ? '#6b7280' : '#9ca3af',
      checkedStrikethrough: true,
      checkboxBorderRadius: 6,
    },
  };

  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        markdown={markdown}
        markdownStyle={markdownStyle}
        flavor="github"
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
});
