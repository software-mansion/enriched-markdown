import { EnrichedMarkdownText } from 'react-native-enriched-markdown';

const markdown = `- First
- Second

> A quote

$E = mc^2$`;

export default function App() {
  return (
    <EnrichedMarkdownText
      markdown={markdown}
      // Translates the strings VoiceOver / TalkBack speak. Placeholders like
      // {n} and {latex} are substituted natively and must be kept.
      accessibilityLabels={{
        list: { bulletPoint: 'Punkt', orderedItem: 'Element {n}' },
        blockquote: { quote: 'Zitat' },
        math: { equation: 'Formel: {latex}' },
      }}
    />
  );
}
