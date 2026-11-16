import { useState } from 'react';
import { ScrollView, StyleSheet, Text } from 'react-native';
import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { storyMeta } from '../shared/storyMeta';
import type { TextStory } from '../shared/storyTypes';

const FOREST_URL =
  'https://images.unsplash.com/photo-1448375240586-882707db888b?w=800';
const MARKDOWN = `Select some of this **bold** text, then use Copy, Copy as Markdown, or ⌘C / Ctrl+C.

> Text in a quote copies too.

![Forest](${FOREST_URL})`;

function SelectionCopyExample({
  flavor = 'github',
}: {
  flavor?: 'commonmark' | 'github';
}) {
  const [result, setResult] = useState('No copy yet');
  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text>
        Copy a selection from the menu or with the keyboard shortcut. The last
        onSelectionCopy event shows below. Select across the image for Copy
        Image URL.
      </Text>
      <Text testID="selection-copy-result">{result}</Text>
      <EnrichedMarkdownText
        markdown={MARKDOWN}
        flavor={flavor}
        onSelectionCopy={({ text, format, selection }) =>
          setResult(
            `${format} ${selection.start}-${selection.end}: ${JSON.stringify(text)}`
          )
        }
      />
    </ScrollView>
  );
}

export default storyMeta('Props', 'Selection Copy');

export const Default: TextStory = {
  args: { markdown: MARKDOWN },
  render: () => <SelectionCopyExample />,
};

export const CommonMark: TextStory = {
  args: { markdown: MARKDOWN },
  render: () => <SelectionCopyExample flavor="commonmark" />,
};

const styles = StyleSheet.create({
  container: { padding: 16, gap: 16 },
});
