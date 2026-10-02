import { StyleSheet } from 'react-native';
import { EnrichedMarkdownTextInput } from 'react-native-enriched-markdown';

export default function App() {
  return (
    <EnrichedMarkdownTextInput
      style={styles.input}
      defaultValue="Base **text** styling comes from `style`."
    />
  );
}

const styles = StyleSheet.create({
  input: {
    fontSize: 18,
    color: '#111827',
    padding: 12,
    minHeight: 120,
    backgroundColor: '#F9FAFB',
    borderRadius: 8,
  },
});
