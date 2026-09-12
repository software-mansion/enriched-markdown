import React from 'react';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import { numberControl } from '../shared/storybookMarkdownStyles';
import type { TextStory } from '../shared/storyTypes';

type EllipsizeMode = 'head' | 'middle' | 'tail' | 'clip';

type NumberOfLinesStoryExtra = {
  numberOfLines: number;
  ellipsizeMode: EllipsizeMode;
};

const MARKDOWN = `This is a longer message **preview** that should fill the available width and then be clamped to a fixed number of lines, ending with an ellipsis when it overflows.

A second paragraph with a [link](https://swmansion.com) and some \`inline code\` so truncation is visible across mixed inline styles.

- A list item that also participates in the line count
- Another list item further down the block`;

const ELLIPSIZE_OPTIONS: EllipsizeMode[] = ['head', 'middle', 'tail', 'clip'];

const argTypes = {
  numberOfLines: numberControl(
    'numberOfLines — clamp the rendered markdown to N lines. 0 means unlimited.',
    { min: 0, max: 6, step: 1 }
  ),
  ellipsizeMode: {
    options: ELLIPSIZE_OPTIONS,
    control: { type: 'inline-radio' as const },
    description:
      "Where the ellipsis is placed when truncated by numberOfLines. 'clip' cuts at the line boundary with no ellipsis. Only takes effect when numberOfLines > 0.",
  },
};

export default storyMeta('Props', 'Number Of Lines');

export const Default: TextStory<NumberOfLinesStoryExtra> = {
  args: {
    markdown: MARKDOWN,
    numberOfLines: 2,
    ellipsizeMode: 'tail',
    containerStyle: {
      borderWidth: 1,
      borderColor: '#c9c9c9',
      borderRadius: 8,
      padding: 8,
    },
  },
  argTypes,
  render: ({ numberOfLines, ellipsizeMode, ...args }) => (
    <EnrichedMarkdownTextStory
      title="Number Of Lines"
      description="CommonMark only. Clamp the content to numberOfLines and pick where the ellipsis goes with ellipsizeMode ('clip' = no glyph). Set numberOfLines to 0 for unlimited. The bordered box shows the text filling the full width before it wraps and truncates."
      {...args}
      numberOfLines={numberOfLines}
      ellipsizeMode={ellipsizeMode}
    />
  ),
};
