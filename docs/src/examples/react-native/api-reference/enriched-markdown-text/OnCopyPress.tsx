import { EnrichedMarkdownText } from 'react-native-enriched-markdown';

const markdown = '```ts\nconst greeting = "hello";\n```';

export default function App() {
  return (
    <EnrichedMarkdownText
      flavor="github"
      markdown={markdown}
      // Fires from the code block header copy button, the long-press "Copy"
      // action, or the VoiceOver copy action. Not for "Copy as Markdown".
      onCopyPress={({ code, language }) => {
        console.log(`Copied ${language} code:`, code);
      }}
    />
  );
}
