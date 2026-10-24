import { EnrichedMarkdownText } from 'react-native-enriched-markdown';

const markdown =
  'هذه فقرة عربية\n\n' +
  'This English paragraph stays LTR.\n\n' +
  '123 456 789.';

export default function App() {
  return (
    <EnrichedMarkdownText
      // 'first-strong' (default) resolves each paragraph from its first strong
      // character. Force a side with 'ltr' / 'rtl', or match RN with 'auto'.
      writingDirection="first-strong"
      markdown={markdown}
    />
  );
}
