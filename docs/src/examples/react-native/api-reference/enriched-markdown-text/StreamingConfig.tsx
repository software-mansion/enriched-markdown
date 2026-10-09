import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { useEffect, useState } from 'react';

const full = `Here are the results:

| Model | Score |
| ----- | ----: |
| A     |    91 |
| B     |    87 |

\`\`\`ts
const score = results.at(0);
\`\`\`
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

  return (
    <EnrichedMarkdownText
      markdown={markdown}
      flavor="github"
      streamingAnimation
      streamingConfig={{
        // Hold incomplete tables back until they are complete...
        tableMode: 'hidden',
        // ...but stream code line-by-line as it arrives.
        codeBlockMode: 'progressive',
      }}
    />
  );
}
