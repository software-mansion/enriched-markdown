import type { ReactNode } from 'react';
import { ScrollView, StyleSheet, Text, View } from 'react-native';
import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { storyMeta } from '../shared/storyMeta';
import type { TextStory } from '../shared/storyTypes';

// Regression coverage for the iOS selection highlight vanishing inside boxes:
// UIKit draws the highlight beneath the text view's text drawing, so the code
// block, inline code and blockquote fills painted there covered it. Long-press
// a word inside each box: it must show the same highlight as the plain
// paragraph (the control). Opaque box colors make a regression obvious.

const markdown = [
  'Plain paragraph text is the control.',
  'Inline `code with a background` in a sentence.',
  '> Quoted text with a background.',
  '- A code block nested in a list item:\n\n  ```\n  npm install example\n  ```',
  '```\nconst topLevel = "code block";\n```',
].join('\n\n');

const markdownStyle = {
  code: { backgroundColor: '#FDE68A', borderColor: '#F59E0B' },
  codeBlock: { backgroundColor: '#1F2937', color: '#F9FAFB' },
  blockquote: { backgroundColor: '#E5E7EB' },
};

const Frame = ({ label, children }: { label: string; children: ReactNode }) => (
  <View style={styles.frameWrap}>
    <Text style={styles.frameLabel}>{label}</Text>
    {children}
  </View>
);

export default storyMeta('Regression', 'Selection Highlight In Boxes');

export const Default: TextStory = {
  args: { markdown },
  render: () => (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.title}>Selection highlight in boxes</Text>
      <Text style={styles.description}>
        Long-press a word inside the inline code, quote and code blocks. Each
        selection must be highlighted like the plain paragraph.
      </Text>
      <Frame label="flavor: commonmark">
        <EnrichedMarkdownText
          markdown={markdown}
          markdownStyle={markdownStyle}
          flavor="commonmark"
        />
      </Frame>
      <Frame label="flavor: github (nested code block, inline code)">
        <EnrichedMarkdownText
          markdown={markdown}
          markdownStyle={markdownStyle}
          flavor="github"
        />
      </Frame>
    </ScrollView>
  ),
};

const styles = StyleSheet.create({
  container: {
    padding: 16,
    gap: 16,
  },
  title: {
    fontSize: 20,
    fontWeight: '700',
  },
  description: {
    fontSize: 14,
    color: '#555',
  },
  frameWrap: {
    gap: 4,
  },
  frameLabel: {
    fontSize: 12,
    color: '#888',
  },
});
