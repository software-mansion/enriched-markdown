import { EnrichedMarkdownText } from 'react-native-enriched-markdown';

const markdown =
  'A long paragraph whose final line will not be left with a single orphaned ' +
  'word once push-out kicks in on iOS 14 and later.';

export default function App() {
  return (
    <EnrichedMarkdownText
      markdown={markdown}
      // 'none' (default) | 'standard' | 'hangul-word' | 'push-out'.
      lineBreakStrategyIOS="push-out"
    />
  );
}
