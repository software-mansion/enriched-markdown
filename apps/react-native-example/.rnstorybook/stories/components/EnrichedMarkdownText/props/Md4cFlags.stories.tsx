import React from 'react';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import {
  githubFlavorArgTypes,
  type MarkdownFlavor,
} from '../shared/storybookMarkdownStyles';
import { storyMeta } from '../shared/storyMeta';
import type { TextStory } from '../shared/storyTypes';

type Md4cFlagsStoryExtra = {
  underline: boolean;
  superscript: boolean;
  subscript: boolean;
  highlight: boolean;
  latexMath: boolean;
  hardSoftBreaks: boolean;
  flavor: MarkdownFlavor;
};

const MARKDOWN = `_underline_

text^superscript^

text~subscript~

==highlight==

$E = mc^2$

Line one
Line two
Line three`;

const argTypes = {
  underline: {
    control: 'boolean',
    description:
      'md4cFlags.underline — _text_ becomes underline instead of emphasis.',
  },
  superscript: {
    control: 'boolean',
    description: 'md4cFlags.superscript — ^text^ parsing.',
  },
  subscript: {
    control: 'boolean',
    description:
      'md4cFlags.subscript — ~text~ parsing (disables single-tilde strikethrough).',
  },
  highlight: {
    control: 'boolean',
    description: 'md4cFlags.highlight — ==text== parsing.',
  },
  latexMath: {
    control: 'boolean',
    description: 'md4cFlags.latexMath — $...$ and $$...$$ math parsing.',
  },
  hardSoftBreaks: {
    control: 'boolean',
    description:
      'md4cFlags.hardSoftBreaks — treat single newlines as hard line breaks.',
  },
  ...githubFlavorArgTypes('LaTeX math requires flavor="github".'),
};

// Sidebar title uses "Md4c-Flags"; file name follows camelCase convention.
export default storyMeta('Props', 'Md4c-Flags');

export const Default: TextStory<Md4cFlagsStoryExtra> = {
  args: {
    markdown: MARKDOWN,
    underline: true,
    superscript: true,
    subscript: true,
    highlight: true,
    latexMath: true,
    hardSoftBreaks: false,
    flavor: 'github',
  },
  argTypes,
  render: ({
    underline,
    superscript,
    subscript,
    highlight,
    latexMath,
    hardSoftBreaks,
    ...args
  }) => (
    <EnrichedMarkdownTextStory
      title="Md4c-Flags"
      description="Cross-cutting md4cFlags demo. Individual inline/block stories also expose the minimum flag each syntax needs."
      {...args}
      md4cFlags={{
        underline,
        superscript,
        subscript,
        highlight,
        latexMath,
        hardSoftBreaks,
      }}
    />
  ),
};
