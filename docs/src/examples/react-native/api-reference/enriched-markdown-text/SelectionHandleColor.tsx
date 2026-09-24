import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { useColorScheme } from 'react-native';

const markdown = 'Select this text on Android to see the tinted drag handles.';

export default function App() {
  const isDark = useColorScheme() === 'dark';

  return (
    <EnrichedMarkdownText
      markdown={markdown}
      // Colors the selection drag anchors independently of selectionColor.
      // No-op on Android API levels below 29.
      selectionHandleColor={isDark ? '#57b495' : '#3f9e82'}
    />
  );
}
