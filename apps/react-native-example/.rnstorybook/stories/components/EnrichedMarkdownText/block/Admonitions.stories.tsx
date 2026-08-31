import React from 'react';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import {
  admonitionStyledDefaults,
  githubFlavorArgTypes,
  numberControl,
  type AdmonitionStyleControls,
} from '../shared/storybookMarkdownStyles';
import {
  splitStyleControls,
  toAdmonitionStyle,
} from '../shared/storybookStyleBuilders';
import type { StoryArgs, TextStory } from '../shared/storyTypes';

// The blockquote style controls plus a boolean toggle wired to
// md4cFlags.admonitions (on/off instead of an object).
type AdmonitionControls = AdmonitionStyleControls & {
  admonitionsEnabled: boolean;
};

const ALL_TYPES_MARKDOWN = `> [!NOTE]
> Highlights information that users should take into account, even when skimming.

> [!TIP]
> Optional information to help a user be more successful.

> [!IMPORTANT]
> Key information users need to know to achieve their goal.

> [!WARNING]
> Urgent info that needs immediate user attention to avoid problems.

> [!CAUTION]
> Advises about risks or negative outcomes of certain actions.

> Control text showing default blockquote`;

const BLOCK_ELEMENTS_MARKDOWN = `> [!IMPORTANT]
> An admonition can hold many block elements:
>
> ## A heading inside the alert
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
> and a trailing paragraph.`;

const NESTED_MARKDOWN = `> [!WARNING]
> An outer warning alert.
>
> > [!TIP]
> > A tip nested inside the warning.
> >
> > > [!NOTE]
> > > And a note nested one level deeper - each level is its own themed container.`;

const argTypes = {
  admonitionsEnabled: {
    control: 'boolean',
    description:
      'md4cFlags.admonitions - turn the extension off to render plain blockquotes (also forced off when flavor="commonmark")',
  },
  fontSize: numberControl('markdownStyle.blockquote.fontSize', {
    min: 12,
    max: 24,
    step: 1,
  }),
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
  noteColor: {
    control: 'color',
    description: 'markdownStyle.blockquote.admonitions.note.color',
  },
  noteBackgroundColor: {
    control: 'color',
    description: 'markdownStyle.blockquote.admonitions.note.backgroundColor',
  },
  tipColor: {
    control: 'color',
    description: 'markdownStyle.blockquote.admonitions.tip.color',
  },
  tipBackgroundColor: {
    control: 'color',
    description: 'markdownStyle.blockquote.admonitions.tip.backgroundColor',
  },
  importantColor: {
    control: 'color',
    description: 'markdownStyle.blockquote.admonitions.important.color',
  },
  importantBackgroundColor: {
    control: 'color',
    description:
      'markdownStyle.blockquote.admonitions.important.backgroundColor',
  },
  warningColor: {
    control: 'color',
    description: 'markdownStyle.blockquote.admonitions.warning.color',
  },
  warningBackgroundColor: {
    control: 'color',
    description: 'markdownStyle.blockquote.admonitions.warning.backgroundColor',
  },
  cautionColor: {
    control: 'color',
    description: 'markdownStyle.blockquote.admonitions.caution.color',
  },
  cautionBackgroundColor: {
    control: 'color',
    description: 'markdownStyle.blockquote.admonitions.caution.backgroundColor',
  },
};

function renderAdmonition(
  title: string,
  description: string,
  args: StoryArgs<AdmonitionControls>
) {
  const { admonitionsEnabled = true, ...styleArgs } = args;
  const { controls, rest } = splitStyleControls(
    styleArgs,
    admonitionStyledDefaults
  );
  return (
    <EnrichedMarkdownTextStory
      title={title}
      description={description}
      {...rest}
      md4cFlags={{ admonitions: admonitionsEnabled }}
      style={{ blockquote: toAdmonitionStyle(controls) }}
    />
  );
}

const flavorArgTypes = githubFlavorArgTypes(
  'Admonitions require flavor="github". commonmark forces the extension off, so `> [!NOTE]` renders as a plain blockquote.'
);

const admonitionStoryBase = {
  argTypes: { ...argTypes, ...flavorArgTypes },
  args: {
    ...admonitionStyledDefaults,
    admonitionsEnabled: true,
    flavor: 'github' as const,
  },
};

export default storyMeta('Block', 'Admonitions');

export const AllTypes: TextStory<AdmonitionControls> = {
  ...admonitionStoryBase,
  args: {
    ...admonitionStoryBase.args,
    markdown: ALL_TYPES_MARKDOWN,
  },
  render: (args) =>
    renderAdmonition(
      'Admonitions',
      'Every GitHub alert type (note, tip, important, warning, caution), each a themed blockquote with an icon + title header. Toggle "admonitionsEnabled" off, or flip flavor to commonmark, to render them as plain blockquotes; tune the per-type colors via the controls.',
      args
    ),
};

export const WithBlockElements: TextStory<AdmonitionControls> = {
  ...admonitionStoryBase,
  args: {
    ...admonitionStoryBase.args,
    markdown: BLOCK_ELEMENTS_MARKDOWN,
  },
  render: (args) =>
    renderAdmonition(
      'Admonition with Block Elements',
      'An admonition holding a heading, lists, a fenced code block and a table - each rendered as its own segment inside the alert container.',
      args
    ),
};

export const Nested: TextStory<AdmonitionControls> = {
  ...admonitionStoryBase,
  args: {
    ...admonitionStoryBase.args,
    markdown: NESTED_MARKDOWN,
  },
  render: (args) =>
    renderAdmonition(
      'Nested Admonition',
      'Admonitions nested three levels deep - each level is its own recursive themed container.',
      args
    ),
};
