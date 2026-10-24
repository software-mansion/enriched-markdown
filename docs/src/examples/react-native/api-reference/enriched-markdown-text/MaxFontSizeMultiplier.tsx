import { EnrichedMarkdownText } from 'react-native-enriched-markdown';

const markdown = 'This text scales with accessibility settings, but never past 1.5x.';

export default function App() {
  return (
    <EnrichedMarkdownText
      markdown={markdown}
      allowFontScaling
      // Caps how far the OS Text Size setting can enlarge the text.
      maxFontSizeMultiplier={1.5}
    />
  );
}
