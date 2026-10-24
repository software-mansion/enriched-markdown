import { EnrichedMarkdownText } from 'react-native-enriched-markdown';

const markdown = 'This text ignores the OS **Text Size** accessibility setting.';

export default function App() {
  return (
    <EnrichedMarkdownText
      markdown={markdown}
      // When false, text stays at its designed size regardless of the user's
      // Text Size / Font Size accessibility setting.
      allowFontScaling={false}
    />
  );
}
