import React from 'react';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import type { TextStory } from '../shared/storyTypes';

type AccessibilityLabelsStoryExtra = {
  bulletPoint: string;
  nestedBulletPoint: string;
  orderedItem: string;
  nestedOrderedItem: string;
  blockquote: string;
  nestedBlockquote: string;
  tableRow: string;
  mathEquation: string;
  rotorHeadings: string;
  rotorLinks: string;
  rotorImages: string;
};

const MARKDOWN = `# Heading level 1

A paragraph with an inline [link](https://example.com).

A paragraph with **bold text**, *italic text*, __underline text__, ~~strikethrough~~ and \`inline code\` mixed together.

- Top-level bullet
- Another bullet
  - Nested bullet
  - Another nested bullet

1. Top-level ordered item
2. Another ordered item
   1. Nested ordered item
   2. Another nested ordered item

> A top-level blockquote line.
>
> > A nested blockquote line.

| Column A | Column B |
|----------|----------|
| Cell A1  | Cell B1  |
| Cell A2  | Cell B2  |

$$E = mc^2$$

![Sample image](https://placehold.co/200x80/png?text=Image)`;

const argTypes = {
  bulletPoint: {
    control: 'text',
    description:
      'accessibilityLabels.list.bulletPoint — top-level unordered item announcement.',
  },
  nestedBulletPoint: {
    control: 'text',
    description:
      'accessibilityLabels.list.nestedBulletPoint — nested unordered item announcement.',
  },
  orderedItem: {
    control: 'text',
    description:
      'accessibilityLabels.list.orderedItem — ordered item announcement. `{n}` → 1-based index.',
  },
  nestedOrderedItem: {
    control: 'text',
    description:
      'accessibilityLabels.list.nestedOrderedItem — nested ordered item. `{n}` → 1-based index.',
  },
  blockquote: {
    control: 'text',
    description:
      'accessibilityLabels.blockquote.quote — appended to elements that sit inside a top-level blockquote.',
  },
  nestedBlockquote: {
    control: 'text',
    description:
      'accessibilityLabels.blockquote.nestedQuote — appended to elements that sit inside a nested blockquote.',
  },
  tableRow: {
    control: 'text',
    description:
      'accessibilityLabels.table.row — table row. `{n}` → 1-based row index, `{content}` → joined cell texts.',
  },
  mathEquation: {
    control: 'text',
    description:
      'accessibilityLabels.math.equation — math equation. `{speech}` → the formula read in English, `{latex}` → equation source.',
  },
  rotorHeadings: {
    control: 'text',
    description:
      'accessibilityLabels.rotor.headings — VoiceOver headings rotor name (iOS only).',
  },
  rotorLinks: {
    control: 'text',
    description:
      'accessibilityLabels.rotor.links — VoiceOver links rotor name (iOS only).',
  },
  rotorImages: {
    control: 'text',
    description:
      'accessibilityLabels.rotor.images — VoiceOver images rotor name (iOS only).',
  },
};

export default storyMeta('Props', 'Accessibility Labels');

export const Default: TextStory<AccessibilityLabelsStoryExtra> = {
  args: {
    markdown: MARKDOWN,
    bulletPoint: 'Aufzählungspunkt',
    nestedBulletPoint: 'Verschachtelter Aufzählungspunkt',
    orderedItem: 'Listenelement {n}',
    nestedOrderedItem: 'Verschachteltes Listenelement {n}',
    blockquote: 'Zitat',
    nestedBlockquote: 'Verschachteltes Zitat',
    tableRow: 'Zeile {n}: {content}',
    mathEquation: 'Formel: {speech}',
    rotorHeadings: 'Überschriften',
    rotorLinks: 'Links',
    rotorImages: 'Bilder',
  },
  argTypes,
  render: ({
    bulletPoint,
    nestedBulletPoint,
    orderedItem,
    nestedOrderedItem,
    blockquote,
    nestedBlockquote,
    tableRow,
    mathEquation,
    rotorHeadings,
    rotorLinks,
    rotorImages,
    ...args
  }) => (
    <EnrichedMarkdownTextStory
      title="Accessibility Labels"
      description="Strings spoken by VoiceOver (iOS) and TalkBack (Android). Edit any field and toggle the screen reader to hear the override. Placeholders ({n}, {content}, {speech}, {latex}) are substituted at speak time. Rotor labels are iOS-only."
      flavor="github"
      md4cFlags={{ underline: true, latexMath: true }}
      {...args}
      accessibilityLabels={{
        list: {
          bulletPoint,
          nestedBulletPoint,
          orderedItem,
          nestedOrderedItem,
        },
        blockquote: { quote: blockquote, nestedQuote: nestedBlockquote },
        table: { row: tableRow },
        math: { equation: mathEquation },
        rotor: {
          headings: rotorHeadings,
          links: rotorLinks,
          images: rotorImages,
        },
      }}
    />
  ),
};
