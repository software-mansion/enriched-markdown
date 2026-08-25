import React from 'react';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import {
  fontFamilyControl,
  fontWeightControl,
  listStyledDefaults,
  type ListStyleControls,
  numberControl,
} from '../shared/storybookMarkdownStyles';
import {
  splitStyleControls,
  toListStyle,
} from '../shared/storybookStyleBuilders';
import type { StoryArgs, TextStory } from '../shared/storyTypes';

const MARKDOWN = `- Apples
- Bananas
- Mango
* Dragonfruit
* Guava
* Fig`;

const ORDERED_MARKDOWN = `1. Preheat oven to 180C
2. Mix flour, sugar, and butter
3. Add eggs and vanilla extract
4. Pour into a greased tin
5. Bake for 30 minutes`;

const NESTED_UNORDERED_MARKDOWN = `- Item
  - Nested
    - Deep nested
    - Deep nested
  - Nested
- Item`;

const NESTED_ORDERED_MARKDOWN = `1. First
   1. Nested
      1. Deep nested
      2. Deep nested
   2. Nested
2. First`;

const MIXED_MARKDOWN = `- Frontend
  - React
    - Hooks
    - Components
  - Vue
- Backend
  - Node.js
  - Python
    1. Django
    2. FastAPI`;

const argTypes = {
  fontSize: numberControl('markdownStyle.list.fontSize', {
    min: 12,
    max: 24,
    step: 1,
  }),
  fontFamily: fontFamilyControl('markdownStyle.list.fontFamily'),
  fontWeight: fontWeightControl('markdownStyle.list.fontWeight'),
  color: {
    control: 'color',
    description: 'markdownStyle.list.color',
  },
  marginTop: numberControl('markdownStyle.list.marginTop', {
    min: 0,
    max: 48,
    step: 2,
  }),
  marginBottom: numberControl('markdownStyle.list.marginBottom', {
    min: 0,
    max: 48,
    step: 2,
  }),
  lineHeight: numberControl('markdownStyle.list.lineHeight', {
    min: 16,
    max: 40,
    step: 1,
  }),
  bulletColor: {
    control: 'color',
    description: 'markdownStyle.list.bulletColor',
  },
  bulletSize: numberControl('markdownStyle.list.bulletSize', {
    min: 2,
    max: 12,
    step: 1,
  }),
  markerMinWidth: numberControl('markdownStyle.list.markerMinWidth', {
    min: 0,
    max: 48,
    step: 2,
  }),
  markerColor: {
    control: 'color',
    description: 'markdownStyle.list.markerColor',
  },
  markerFontWeight: fontWeightControl('markdownStyle.list.markerFontWeight'),
  gapWidth: numberControl('markdownStyle.list.gapWidth', {
    min: 0,
    max: 24,
    step: 2,
  }),
  marginLeft: numberControl('markdownStyle.list.marginLeft', {
    min: 0,
    max: 48,
    step: 4,
  }),
  itemSpacing: numberControl('markdownStyle.list.itemSpacing', {
    min: 0,
    max: 32,
    step: 2,
  }),
};

function renderList(
  title: string,
  description: string,
  args: StoryArgs<ListStyleControls>
) {
  const { controls, rest } = splitStyleControls(args, listStyledDefaults);
  return (
    <EnrichedMarkdownTextStory
      title={title}
      description={description}
      {...rest}
      style={{ list: toListStyle(controls) }}
    />
  );
}

const listStoryBase = {
  argTypes,
  args: listStyledDefaults,
};

export default storyMeta('Block', 'Lists');

export const Default: TextStory<ListStyleControls> = {
  ...listStoryBase,
  args: {
    ...listStoryBase.args,
    markdown: MARKDOWN,
  },
  render: (args) =>
    renderList(
      'Lists',
      'Unordered lists via - or *. Use the controls to tune markdownStyle.list.',
      args
    ),
};

export const Ordered: TextStory<ListStyleControls> = {
  ...listStoryBase,
  args: {
    ...listStoryBase.args,
    markdown: ORDERED_MARKDOWN,
  },
  render: (args) =>
    renderList(
      'Ordered List',
      'Ordered lists via 1. syntax. Use the controls to tune markdownStyle.list.',
      args
    ),
};

export const NestedUnordered: TextStory<ListStyleControls> = {
  ...listStoryBase,
  args: {
    ...listStoryBase.args,
    markdown: NESTED_UNORDERED_MARKDOWN,
  },
  render: (args) =>
    renderList(
      'Nested Unordered List',
      'Nest unordered items with indentation. Use the controls to tune markdownStyle.list.',
      args
    ),
};

export const NestedOrdered: TextStory<ListStyleControls> = {
  ...listStoryBase,
  args: {
    ...listStoryBase.args,
    markdown: NESTED_ORDERED_MARKDOWN,
  },
  render: (args) =>
    renderList(
      'Nested Ordered List',
      'Nest ordered items with indentation. Use the controls to tune markdownStyle.list.',
      args
    ),
};

export const Mixed: TextStory<ListStyleControls> = {
  ...listStoryBase,
  args: {
    ...listStoryBase.args,
    markdown: MIXED_MARKDOWN,
  },
  render: (args) =>
    renderList(
      'Mixed Nested List',
      'Mix unordered and ordered nesting. Use the controls to tune markdownStyle.list.',
      args
    ),
};
