import React from 'react';
import { Image } from 'react-native';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import {
  imageStyledDefaults,
  type ImageStyleControls,
  numberControl,
} from '../shared/storybookMarkdownStyles';
import {
  splitStyleControls,
  toImageStyle,
} from '../shared/storybookStyleBuilders';
import type { TextStory } from '../shared/storyTypes';

const MARKDOWN =
  '![Misty forest at sunrise](https://images.unsplash.com/photo-1448375240586-882707db888b?w=800)';

const LOCAL_ASSET_URI = Image.resolveAssetSource(
  require('../../../../../src/assets/logo.png')
).uri;

const DATA_URI =
  'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAIAAAAlC+aJAAAAeklEQVR42u3asQnAIBQE0D9JILhDyFwZyUW1E4uki5jgg19e4auOAyPtx68vAABeBEQu7c7tur0+MysPADAK8LWHPuUBAAAAAMYANDEAAACAPaCJAQAAAOwBTQwAAABgD2hiAAAAAHtAEwMAAADYA5oYYCWAn7sACwIqZZCNkUg0NTIAAAAASUVORK5CYII=';

const argTypes = {
  height: numberControl('markdownStyle.image.height', {
    min: 80,
    max: 400,
    step: 10,
  }),
  maxHeight: numberControl('markdownStyle.image.maxHeight (0 = off)', {
    min: 0,
    max: 400,
    step: 10,
  }),
  aspectRatio: numberControl('markdownStyle.image.aspectRatio (0 = off)', {
    min: 0,
    max: 3,
    step: 0.1,
  }),
  resizeMode: {
    options: ['', 'contain', 'cover', 'stretch', 'center', 'none'] as const,
    control: { type: 'select' as const },
    description: "markdownStyle.image.resizeMode ('' = legacy sizing)",
  },
  borderRadius: numberControl('markdownStyle.image.borderRadius', {
    min: 0,
    max: 24,
    step: 2,
  }),
  marginTop: numberControl('markdownStyle.image.marginTop', {
    min: 0,
    max: 32,
    step: 2,
  }),
  marginBottom: numberControl('markdownStyle.image.marginBottom', {
    min: 0,
    max: 32,
    step: 2,
  }),
};

export default storyMeta('Block', 'Image');

export const Default: TextStory<ImageStyleControls> = {
  args: {
    markdown: MARKDOWN,
    ...imageStyledDefaults,
  },
  argTypes,
  render: (args) => {
    const { controls, rest } = splitStyleControls(args, imageStyledDefaults);
    return (
      <EnrichedMarkdownTextStory
        title="Image"
        description="Block images via ![alt](url). Use the controls to tune markdownStyle.image."
        {...rest}
        style={{ image: toImageStyle(controls) }}
      />
    );
  },
};

export const LocalAsset: TextStory<ImageStyleControls> = {
  args: {
    markdown: `![Bundled logo](${LOCAL_ASSET_URI})`,
    ...imageStyledDefaults,
  },
  argTypes,
  render: (args) => {
    const { controls, rest } = splitStyleControls(args, imageStyledDefaults);
    return (
      <EnrichedMarkdownTextStory
        title="Local asset image"
        description={`A require()'d asset resolved via Image.resolveAssetSource. In dev this is a Metro http URL; in a release build it becomes a drawable resource name (Android) or a bundle file:// URL (iOS), exercising the local image loaders. Resolved to: ${LOCAL_ASSET_URI}`}
        {...rest}
        style={{ image: toImageStyle(controls) }}
      />
    );
  },
};

export const DataUri: TextStory<ImageStyleControls> = {
  args: {
    markdown: `![Checkerboard](${DATA_URI})`,
    ...imageStyledDefaults,
  },
  argTypes,
  render: (args) => {
    const { controls, rest } = splitStyleControls(args, imageStyledDefaults);
    return (
      <EnrichedMarkdownTextStory
        title="Data URI image"
        description="A base64 data: URI. On Android this exercises the local image loader in every build mode (dev included); on iOS data: URLs are served natively by NSURLSession."
        {...rest}
        style={{ image: toImageStyle(controls) }}
      />
    );
  },
};
