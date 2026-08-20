import React from 'react';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import {
  blockquoteStyledDefaults,
  fontFamilyControl,
  fontWeightControl,
  githubFlavorArgTypes,
  type BlockquoteStyleControls,
  numberControl,
} from '../shared/storybookMarkdownStyles';
import {
  splitStyleControls,
  toBlockquoteStyle,
} from '../shared/storybookStyleBuilders';
import type { StoryArgs, TextStory } from '../shared/storyTypes';

const MARKDOWN = `> this is a text inside a blockquote

> this is also a text inside a blockquote`;

const NESTED_MARKDOWN = `> top-level blockquote
>> nested blockquote inside the first
>>> deeply nested blockquote`;

const BLOCK_ELEMENTS_MARKDOWN = `> Blockquote containing several block elements:
>
> ## A heading inside the quote
>
> A paragraph with **bold**, _italic_ and a [link](https://swmansion.com).
>
> - first bullet
> - second bullet
>
> 1. ordered one
> 2. ordered two
>
> \`\`\`ts
> const answer = 42;
> \`\`\`
>
> | Column A | Column B |
> | -------- | -------- |
> | 1        | 2        |
>
> $$E = mc^2$$
>
> > a nested blockquote inside
>
> and a trailing paragraph.`;

const argTypes = {
  fontSize: numberControl('markdownStyle.blockquote.fontSize', {
    min: 12,
    max: 24,
    step: 1,
  }),
  fontFamily: fontFamilyControl('markdownStyle.blockquote.fontFamily'),
  fontWeight: fontWeightControl('markdownStyle.blockquote.fontWeight'),
  color: {
    control: 'color',
    description: 'markdownStyle.blockquote.color',
  },
  marginTop: numberControl('markdownStyle.blockquote.marginTop', {
    min: 0,
    max: 48,
    step: 2,
  }),
  marginBottom: numberControl('markdownStyle.blockquote.marginBottom', {
    min: 0,
    max: 48,
    step: 2,
  }),
  lineHeight: numberControl('markdownStyle.blockquote.lineHeight', {
    min: 16,
    max: 40,
    step: 1,
  }),
  borderColor: {
    control: 'color',
    description: 'markdownStyle.blockquote.borderColor',
  },
  borderWidth: numberControl('markdownStyle.blockquote.borderWidth', {
    min: 1,
    max: 8,
    step: 1,
  }),
  gapWidth: numberControl('markdownStyle.blockquote.gapWidth', {
    min: 0,
    max: 32,
    step: 2,
  }),
  backgroundColor: {
    control: 'color',
    description: 'markdownStyle.blockquote.backgroundColor',
  },
  borderRadius: numberControl('markdownStyle.blockquote.borderRadius', {
    min: 0,
    max: 16,
    step: 1,
  }),
  padding: numberControl('markdownStyle.blockquote.padding', {
    min: 0,
    max: 32,
    step: 2,
  }),
};

function renderBlockquote(
  title: string,
  description: string,
  args: StoryArgs<BlockquoteStyleControls>
) {
  const { controls, rest } = splitStyleControls(args, blockquoteStyledDefaults);
  return (
    <EnrichedMarkdownTextStory
      title={title}
      description={description}
      {...rest}
      style={{ blockquote: toBlockquoteStyle(controls) }}
    />
  );
}

const flavorArgTypes = githubFlavorArgTypes(
  'commonmark renders quotes inline via spans; github renders each quote as a recursive container view (its own padding/background, nested code blocks become real code-block containers).'
);

const blockquoteStoryBase = {
  argTypes: { ...argTypes, ...flavorArgTypes },
  args: { ...blockquoteStyledDefaults, flavor: 'github' as const },
};

export default storyMeta('Block', 'Blockquote');

export const Default: TextStory<BlockquoteStyleControls> = {
  ...blockquoteStoryBase,
  args: {
    ...blockquoteStoryBase.args,
    markdown: MARKDOWN,
  },
  render: (args) =>
    renderBlockquote(
      'Blockquote',
      'Lines prefixed with >. Flip the flavor control between commonmark and github to compare the inline (span) and container renderers. Use the controls to tune markdownStyle.blockquote.',
      args
    ),
};

export const Nested: TextStory<BlockquoteStyleControls> = {
  ...blockquoteStoryBase,
  args: {
    ...blockquoteStoryBase.args,
    markdown: NESTED_MARKDOWN,
  },
  render: (args) =>
    renderBlockquote(
      'Nested Blockquote',
      'Nest blockquotes with multiple > markers. Flip flavor to compare commonmark (inline spans) with github (one recursive container box per level). Use the controls to tune markdownStyle.blockquote.',
      args
    ),
};

export const WithBlockElements: TextStory<BlockquoteStyleControls> = {
  ...blockquoteStoryBase,
  args: {
    ...blockquoteStoryBase.args,
    markdown: BLOCK_ELEMENTS_MARKDOWN,
  },
  render: (args) =>
    renderBlockquote(
      'Blockquote with Block Elements',
      'A blockquote holding many block elements - heading, lists, a fenced code block, a table, display math and a nested quote. With flavor="github" each becomes its own segment view (code block, table, math and nested quote as real containers) nested in the quote; with flavor="commonmark" they render inline. Use the controls to tune markdownStyle.blockquote.',
      args
    ),
};
