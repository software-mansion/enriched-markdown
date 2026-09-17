import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { View, Text, StyleSheet, useColorScheme } from 'react-native';
import { useState } from 'react';
import { defaultMarkdownStyle } from './theme';

const markdown = `- [x] Buy groceries
- [ ] Walk the dog
- [ ] Water the plants
`;

export default function App() {
  const isDark = useColorScheme() === 'dark';
  const [status, setStatus] = useState('Tap a checkbox above.');

  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        markdown={markdown}
        flavor="github"
        markdownStyle={defaultMarkdownStyle(isDark)}
        onTaskListItemPress={({ index, checked, text }) =>
          setStatus(
            `Task ${index} (${text}) is now ${checked ? 'checked' : 'unchecked'}.`
          )
        }
      />
      <Text style={styles.status}>{status}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
  status: { fontSize: 14, fontStyle: 'italic', color: '#8a90a6' },
});
