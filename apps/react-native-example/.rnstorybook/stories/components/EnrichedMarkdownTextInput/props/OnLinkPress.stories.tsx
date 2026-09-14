import React from 'react';
import { Alert } from 'react-native';
import { EnrichedMarkdownTextInputStory } from '../EnrichedMarkdownTextInputStory';
import { storyMeta } from '../shared/storyMeta';
import type { InputStory } from '../shared/storyTypes';

type OnLinkPressStoryExtra = {
  linkPressEnabled: boolean;
};

export default storyMeta('Props', 'Link Press');

export const Default: InputStory<OnLinkPressStoryExtra> = {
  args: {
    initialMarkdown:
      'Tap [this link](https://reactnative.dev) while the input is not focused. Mentions like [@Alice](user://u_1) and typed URLs (try "swmansion.com ") are pressable too.',
    linkPressEnabled: true,
  },
  argTypes: {
    linkPressEnabled: {
      control: 'boolean',
      description:
        'Toggle passing the onLinkPress handler. Without it, every tap focuses the input (the default behavior).',
    },
    onLinkPress: { action: 'onLinkPress' },
  },
  render: ({ linkPressEnabled, onLinkPress, ...args }) => (
    <EnrichedMarkdownTextInputStory
      title="Link Press"
      description="With onLinkPress set, tapping a link while the input is NOT focused fires the callback and consumes the tap — the input does not focus and the keyboard stays closed. While focused, taps place the cursor as usual and links are inert; blur the input to make them pressable again."
      {...args}
      onLinkPress={
        linkPressEnabled
          ? (event) => {
              onLinkPress?.(event);
              Alert.alert('Link pressed', event.url, [{ text: 'OK' }]);
            }
          : undefined
      }
    />
  ),
};
