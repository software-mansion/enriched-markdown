import { StyleSheet, useColorScheme } from 'react-native';
import { EnrichedMarkdownTextInput } from 'react-native-enriched-markdown';
import { defaultInputMarkdownStyle } from './theme';

export default function App() {
  const isDark = useColorScheme() === 'dark';
  return (
    <EnrichedMarkdownTextInput
      style={{ ...styles.input, ...(isDark ? styles.dark : styles.light) }}
      markdownStyle={defaultInputMarkdownStyle(isDark)}
      defaultValue="Base **text** styling comes from the style prop."
    />
  );
}

const styles = StyleSheet.create({
  input: {
    fontSize: 18,
    padding: 12,
    minHeight: 120,
    borderRadius: 8,
  },
  light: { color: '#111827', backgroundColor: '#F9FAFB' },
  dark: { color: '#F9FAFB', backgroundColor: '#1F2433' },
});
