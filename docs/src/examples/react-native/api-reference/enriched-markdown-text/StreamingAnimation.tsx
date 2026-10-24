import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { useEffect, useState } from 'react';

const full = 'Streaming responses fade their new characters in as they arrive.';

export default function App() {
  const [markdown, setMarkdown] = useState('');

  // Reveal the text one word at a time to imitate an LLM stream.
  useEffect(() => {
    const words = full.split(' ');
    let i = 0;
    const id = setInterval(() => {
      i += 1;
      setMarkdown(words.slice(0, i).join(' '));
      if (i >= words.length) clearInterval(id);
    }, 250);
    return () => clearInterval(id);
  }, []);

  return <EnrichedMarkdownText markdown={markdown} streamingAnimation />;
}
