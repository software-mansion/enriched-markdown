import { EnrichedMarkdownText } from 'react-native-enriched-markdown';

const markdown = '```ts\nconst greeting = "hello";\n```';

export default function App() {
  return (
    <EnrichedMarkdownText
      flavor="github"
      markdown={markdown}
      // Setting this arms the block for taps. Text selection, the header copy
      // button, and the long-press menu are unchanged, and a tap never fires
      // while text is being selected.
      onCodeBlockPress={({ code, language }) => {
        console.log(`Tapped ${language} block:`, code);
      }}
    />
  );
}
