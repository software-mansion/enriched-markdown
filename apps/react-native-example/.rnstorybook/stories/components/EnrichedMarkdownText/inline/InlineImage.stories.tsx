import React from 'react';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import {
  inlineImageStyledDefaults,
  type InlineImageStyleControls,
  numberControl,
} from '../shared/storybookMarkdownStyles';
import {
  splitStyleControls,
  toInlineImageStyle,
} from '../shared/storybookStyleBuilders';
import type { TextStory } from '../shared/storyTypes';

const MARKDOWN =
  'Text with an inline image ![tiny](https://placehold.co/100x100/png?text=I) in the flow.';

const argTypes = {
  size: numberControl('markdownStyle.inlineImage.size', {
    min: 12,
    max: 64,
    step: 2,
  }),
};

export default storyMeta('Inline', 'Inline Image');

export const Default: TextStory<InlineImageStyleControls> = {
  args: {
    markdown: MARKDOWN,
    ...inlineImageStyledDefaults,
  },
  argTypes,
  render: (args) => {
    const { controls, rest } = splitStyleControls(
      args,
      inlineImageStyledDefaults
    );
    return (
      <EnrichedMarkdownTextStory
        title="Inline Image"
        description="![alt](url) inside a paragraph uses markdownStyle.inlineImage."
        {...rest}
        style={{ inlineImage: toInlineImageStyle(controls) }}
      />
    );
  },
};

const NON_SQUARE_MARKDOWN = [
  'Wide ![wide](https://placehold.co/400x200/2563eb/ffffff/png?text=WIDE) Catan Hxg',
  'Tall ![tall](https://placehold.co/200x400/dc2626/ffffff/png?text=TALL) Catan Hxg',
  'Square ![square](https://placehold.co/300x300/16a34a/ffffff/png?text=SQ) Catan Hxg',
  'Very wide ![very wide](https://placehold.co/1000x100/7c3aed/ffffff/png?text=10:1) and very tall ![very tall](https://placehold.co/100x1000/ea580c/ffffff/png?text=T) Hxg',
].join('\n\n');

export const NonSquare: TextStory<InlineImageStyleControls> = {
  args: {
    markdown: NON_SQUARE_MARKDOWN,
    ...inlineImageStyledDefaults,
    size: 48,
  },
  argTypes,
  render: (args) => {
    const { controls, rest } = splitStyleControls(
      args,
      inlineImageStyledDefaults
    );
    return (
      <EnrichedMarkdownTextStory
        title="Inline Image: non-square"
        description="A non-square image fits inside its markdownStyle.inlineImage.size square without distortion or cropping (contain), centred on the cap height."
        {...rest}
        style={{ inlineImage: toInlineImageStyle(controls) }}
      />
    );
  },
};
