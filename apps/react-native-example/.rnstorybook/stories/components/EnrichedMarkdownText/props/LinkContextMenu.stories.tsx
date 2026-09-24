import { useState } from 'react';
import { Button, ScrollView, StyleSheet, Text } from 'react-native';
import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import type { LinkContextMenu } from 'react-native-enriched-markdown';
import { storyMeta } from '../shared/storyMeta';
import type { TextStory } from '../shared/storyTypes';

const URL = './notes.md';
const MARKDOWN = `[Root link](${URL}) and [fallback link](./other.md).

> [Quote link](${URL})
>
> > [Nested quote link](${URL})
>
> | Quoted table |
> | --- |
> | [Quoted table link](${URL}) |

| Table |
| --- |
| [Table link](${URL}) |`;

function LinkMenuExample({
  flavor = 'github',
}: {
  flavor?: 'commonmark' | 'github';
}) {
  const [enabled, setEnabled] = useState(true);
  const [result, setResult] = useState('No action');
  const menus: Record<string, LinkContextMenu> = {
    [URL]: {
      title: 'Notes',
      items: [
        {
          text: 'Open notes',
          icon: 'doc.text',
          onPress: ({ url }) => setResult(`Open: ${url}`),
        },
        {
          text: 'Unavailable',
          disabled: true,
          onPress: () => setResult('Unexpected disabled action'),
        },
        {
          text: 'Hidden',
          visible: false,
          onPress: () => setResult('Unexpected hidden action'),
        },
        {
          text: 'Remove bookmark',
          destructive: true,
          onPress: ({ url }) => setResult(`Remove: ${url}`),
        },
      ],
    },
  };
  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text>
        Long-press links on iOS 17+. Configured links show actions; other links
        use the callback. Toggle menus to check removal.
      </Text>
      <Button
        title={enabled ? 'Disable link menus' : 'Enable link menus'}
        onPress={() => setEnabled(!enabled)}
      />
      <Text testID="link-menu-result">{result}</Text>
      <EnrichedMarkdownText
        markdown={MARKDOWN}
        flavor={flavor}
        linkContextMenus={enabled ? menus : undefined}
        onLinkLongPress={({ url }) => setResult(`Fallback: ${url}`)}
      />
    </ScrollView>
  );
}

export default storyMeta('Props', 'Link Context Menu');

export const Default: TextStory = {
  args: { markdown: MARKDOWN },
  render: () => <LinkMenuExample />,
};

export const CommonMark: TextStory = {
  args: { markdown: MARKDOWN },
  render: () => <LinkMenuExample flavor="commonmark" />,
};

const styles = StyleSheet.create({
  container: { padding: 16, gap: 16 },
});
