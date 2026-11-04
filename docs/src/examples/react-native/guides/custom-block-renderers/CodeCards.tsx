import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import type { MarkdownCodeBlock } from 'react-native-enriched-markdown';
import { StyleSheet, Text, View } from 'react-native';
import { useMemo } from 'react';
import { useColorScheme } from 'react-native';
import { defaultMarkdownStyle } from './theme';

const markdown = `# Release notes

\`\`\`diff
- const timeout = 1000;
+ const timeout = 5000;
\`\`\`

\`\`\`bash
yarn add react-native-enriched-markdown
\`\`\`

\`\`\`ts
export const retries = 3;
\`\`\`

> \`\`\`json
> { "quoted": true }
> \`\`\`

- \`\`\`ts
  // In a list, a code block stays native.
  \`\`\`
`;

// For every other language.
function CodeCard({ block }: { block: MarkdownCodeBlock }) {
  return (
    <View style={styles.card}>
      <Text style={styles.label}>{block.language || 'text'}</Text>
      <Text style={styles.code}>{block.code}</Text>
    </View>
  );
}

function Diff({ block }: { block: MarkdownCodeBlock }) {
  return (
    <View style={styles.card}>
      {block.code.split('\n').map((line, index) => (
        <Text
          key={index}
          style={[
            styles.code,
            line.startsWith('+') && styles.added,
            line.startsWith('-') && styles.removed,
          ]}>
          {line}
        </Text>
      ))}
    </View>
  );
}

function Terminal({ block }: { block: MarkdownCodeBlock }) {
  return (
    <View style={[styles.card, styles.terminal]}>
      <Text style={styles.code}>$ {block.code}</Text>
    </View>
  );
}

// Defined once, outside the component, so the renderer keeps its identity.
// Return undefined for a language to keep the native code block.
function code(block: MarkdownCodeBlock) {
  switch (block.language) {
    case 'diff':
      return <Diff block={block} />;
    case 'sh':
    case 'bash':
    case 'zsh':
    case 'shell':
      return <Terminal block={block} />;
    default:
      return <CodeCard block={block} />;
  }
}

export default function App() {
  const isDark = useColorScheme() === 'dark';
  const markdownStyle = useMemo(() => defaultMarkdownStyle(isDark), [isDark]);

  return (
    <View style={styles.container}>
      <EnrichedMarkdownText
        flavor="github"
        markdown={markdown}
        markdownStyle={markdownStyle}
        renderers={{ code }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 12 },
  card: {
    borderRadius: 10,
    padding: 12,
    gap: 4,
    backgroundColor: '#1c1c2e',
  },
  terminal: { backgroundColor: '#0b0b12' },
  label: {
    color: '#8a90b0',
    fontSize: 11,
    fontWeight: '600',
    textTransform: 'uppercase',
  },
  code: { color: '#e4e6f2', fontFamily: 'monospace', fontSize: 13 },
  added: { color: '#7ee2a8' },
  removed: { color: '#ff8f8f' },
});
