import React from 'react';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import {
  videoStyledDefaults,
  type VideoStyleControls,
  numberControl,
  githubFlavorArgTypes,
} from '../shared/storybookMarkdownStyles';
import {
  splitStyleControls,
  toVideoStyle,
} from '../shared/storybookStyleBuilders';
import type { TextStory } from '../shared/storyTypes';

const MARKDOWN =
  '<video src="https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4"></video>';

const MULTIPLE_MARKDOWN = `Some text before the video.

<video src="https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4"></video>

Text between two videos.

<video src="https://interactive-examples.mdn.mozilla.net/media/cc0-videos/friday.mp4"></video>

And some text after.`;

const argTypes = {
  ...githubFlavorArgTypes('Videos require flavor="github".'),
  marginTop: numberControl('markdownStyle.video.marginTop', {
    min: 0,
    max: 32,
    step: 2,
  }),
  marginBottom: numberControl('markdownStyle.video.marginBottom', {
    min: 0,
    max: 32,
    step: 2,
  }),
  borderRadius: numberControl('markdownStyle.video.borderRadius', {
    min: 0,
    max: 24,
    step: 2,
  }),
  aspectRatio: numberControl(
    'markdownStyle.video.aspectRatio (0 = default 16:9)',
    {
      min: 0,
      max: 3,
      step: 0.1,
    }
  ),
  backgroundColor: {
    control: { type: 'color' as const },
    description: 'markdownStyle.video.backgroundColor',
  },
};

export default storyMeta('Block', 'Video');

export const Default: TextStory<VideoStyleControls> = {
  args: {
    markdown: MARKDOWN,
    flavor: 'github',
    ...videoStyledDefaults,
  },
  argTypes,
  render: (args) => {
    const { controls, rest } = splitStyleControls(args, videoStyledDefaults);
    return (
      <EnrichedMarkdownTextStory
        title="Video"
        description='Block videos via <video src="url"> HTML tag. Use the controls to tune markdownStyle.video.'
        {...rest}
        style={{ video: toVideoStyle(controls) }}
      />
    );
  },
};

export const MultipleVideos: TextStory<VideoStyleControls> = {
  args: {
    markdown: MULTIPLE_MARKDOWN,
    flavor: 'github',
    ...videoStyledDefaults,
  },
  argTypes,
  render: (args) => {
    const { controls, rest } = splitStyleControls(args, videoStyledDefaults);
    return (
      <EnrichedMarkdownTextStory
        title="Multiple videos"
        description="Multiple video blocks mixed with text. Videos render as native players (AVPlayerViewController on iOS, ExoPlayer on Android)."
        {...rest}
        style={{ video: toVideoStyle(controls) }}
      />
    );
  },
};
