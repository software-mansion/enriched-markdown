import React from 'react';
import type { EnrichedMarkdownTextProps } from 'react-native-enriched-markdown';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import type { TextStory } from '../shared/storyTypes';

// \foo and \bogus are not real LaTeX commands, so RaTeX cannot render them and
// fires onLatexError; \frac and E = mc^2 render fine and stay silent.
const MARKDOWN = `Valid inline $E = mc^2$ and broken inline $\\foo{x}$.

$$
\\frac{1}{2}
$$

$$
\\bogus{y}
$$`;

type LatexErrorStoryExtra = {
  latexMath: boolean;
  onLatexError?: EnrichedMarkdownTextProps['onLatexError'];
};

const argTypes = {
  flavor: {
    control: { type: 'radio' },
    options: ['github', 'commonmark'],
    description: 'Block math ($$...$$) requires flavor="github".',
  },
  latexMath: {
    control: { type: 'boolean' },
    description: 'md4cFlags.latexMath — enable block and inline math parsing.',
  },
  onLatexError: { action: 'latexError' },
};

export default storyMeta('Props', 'Latex Error');

export const Default: TextStory<LatexErrorStoryExtra> = {
  args: {
    markdown: MARKDOWN,
    flavor: 'github',
    latexMath: true,
  },
  argTypes,
  render: ({ latexMath, onLatexError, ...args }) => (
    <EnrichedMarkdownTextStory
      title="Latex Error"
      description="onLatexError fires once per math expression RaTeX cannot render, with the failing source, the engine message, and displayMode. Watch the Actions tab: the two broken formulas report, the two valid ones stay silent."
      {...args}
      md4cFlags={{ latexMath }}
      onLatexError={onLatexError}
    />
  ),
};
