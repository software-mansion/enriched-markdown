import { useColorScheme } from 'react-native';
import { EnrichedMarkdownTextInput } from 'react-native-enriched-markdown';
import { defaultInputColors, defaultInputMarkdownStyle } from './theme';

export default function App() {
  const isDark = useColorScheme() === 'dark';
  return (
    <EnrichedMarkdownTextInput
      markdownStyle={defaultInputMarkdownStyle(isDark)}
      style={defaultInputColors(isDark)}
      selectionColor="#FDE68A"
      defaultValue="Select this text to see the highlight color."
    />
  );
}
