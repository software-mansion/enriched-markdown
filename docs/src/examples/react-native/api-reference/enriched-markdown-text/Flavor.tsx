import { EnrichedMarkdownText } from 'react-native-enriched-markdown';

const markdown = `| Feature | Supported |
| ------- | :-------: |
| Tables  | Yes       |
| Code    | Yes       |

\`\`\`ts
const x = 1;
\`\`\`
`;

export default function App() {
  return (
    <EnrichedMarkdownText
      // 'github' splits the document into segments and enables GFM tables and
      // block-style fenced code blocks. 'commonmark' (default) renders a single
      // text view.
      flavor="github"
      markdown={markdown}
    />
  );
}
