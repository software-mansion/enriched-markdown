import { useState } from 'react';
import { ScrollView, StyleSheet, Text } from 'react-native';
import {
  EnrichedMarkdownText,
  EnrichedMarkdownTextInput,
} from 'react-native-enriched-markdown';

const markdown = `# Swift Package Manager

Plain, **bold**, __underlined__, *italic*, ~~struck~~ and \`inline code\`. A [link](https://swmansion.com).

Inline math: $E = mc^2$ and $\\frac{a}{b}$.

$$
\\int_0^\\infty e^{-x^2}\\,dx = \\frac{\\sqrt{\\pi}}{2}
$$

\`\`\`swift
let greeting: String = "Hi"
func twice(_ x: Int) -> Int { x * 2 }
\`\`\`

\`\`\`typescript
const answer: number = 42;
\`\`\`

> A quote with **bold** inside.

- item one
- item two
  1. nested

- [x] done
- [ ] to do

| Left | Center |
| --- | :---: |
| a | b |

![React Native logo](https://reactnative.dev/img/tiny_logo.png)

<video src="https://www.w3schools.com/html/mov_bbb.mp4"></video>
`;

export default function App() {
  const [linkCount, setLinkCount] = useState<number>();

  return (
    <ScrollView
      contentInsetAdjustmentBehavior="automatic"
      contentContainerStyle={styles.content}
    >
      <EnrichedMarkdownText
        markdown={markdown}
        flavor="github"
        md4cFlags={{ underline: true, latexMath: true }}
        onLinksChange={(links) => setLinkCount(links.length)}
      />
      <Text style={styles.label}>
        Parser module:{' '}
        {linkCount === undefined ? 'not called' : `${linkCount} link(s)`}
      </Text>
      <Text style={styles.label}>CommonMark:</Text>
      <EnrichedMarkdownText markdown="Plain **CommonMark** text." />
      <Text style={styles.label}>Input:</Text>
      <EnrichedMarkdownTextInput
        placeholder="Type here..."
        style={styles.input}
      />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  content: {
    padding: 16,
  },
  label: {
    marginTop: 16,
    fontWeight: '600',
  },
  input: {
    minHeight: 60,
    borderWidth: 1,
    borderColor: '#ccc',
    padding: 8,
  },
});
