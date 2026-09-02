import { EnrichedMarkdownText } from 'react-native-enriched-markdown';

const markdown = '```ts\nconst greeting = "hello";\n```';

export default function App() {
  return (
    <EnrichedMarkdownText
      flavor="github"
      markdown={markdown}
      // Long-pressing the code block (or a table / block math) no longer opens
      // the copy popup. The header copy button, accessibility copy action, and
      // text-selection menu are unaffected.
      enableBlockContextMenu={false}
    />
  );
}
