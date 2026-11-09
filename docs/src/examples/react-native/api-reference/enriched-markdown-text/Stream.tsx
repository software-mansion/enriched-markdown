import {
  EnrichedMarkdownText,
  createMarkdownStream,
} from 'react-native-enriched-markdown';
import { useEffect, useState } from 'react';

const answer =
  '## A streamed answer\n\nEach **chunk** is appended to the stream, and the view shows it on the next frame - this component never re-renders.';

export default function App() {
  // In an app, keep the stream next to the message it belongs to.
  const [stream] = useState(() => createMarkdownStream());

  useEffect(() => {
    let sent = 0;
    const id = setInterval(() => {
      stream.append(answer.slice(sent, sent + 4));
      sent += 4;
      if (sent >= answer.length) {
        clearInterval(id);
        stream.end();
      }
    }, 50);
    return () => clearInterval(id);
  }, [stream]);

  return <EnrichedMarkdownText stream={stream} />;
}
