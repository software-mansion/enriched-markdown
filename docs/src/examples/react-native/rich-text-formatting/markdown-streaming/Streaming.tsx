import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { useEffect, useState } from 'react';

const fence = '```';

const full = `Here is what I found.

| Model | Score |
| ----- | ----: |
| A     |    91 |
| B     |    87 |

${fence}ts
const best = results.at(0);
${fence}
`;

export default function App() {
  const [markdown, setMarkdown] = useState('');

  // Reveal the document a few characters at a time to imitate an LLM stream.
  useEffect(() => {
    let i = 0;
    const id = setInterval(() => {
      i += 4;
      setMarkdown(full.slice(0, i));
      if (i >= full.length) clearInterval(id);
    }, 60);
    return () => clearInterval(id);
  }, []);

  // Streaming ends once the whole document has arrived.
  return (
    <EnrichedMarkdownText
      markdown={markdown}
      flavor="github"
      streaming={markdown.length < full.length}
      streamingConfig={{ tableMode: 'hidden', codeBlockMode: 'progressive' }}
    />
  );
}
