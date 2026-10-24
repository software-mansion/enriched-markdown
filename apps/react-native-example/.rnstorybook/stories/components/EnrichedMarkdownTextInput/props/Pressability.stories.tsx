import React from 'react';
import { PressabilityStory } from '../EnrichedMarkdownTextInputStory';
import { storyMeta } from '../shared/storyMeta';
import type { InputStory } from '../shared/storyTypes';

export default storyMeta('Props', 'Pressability');

export const Default: InputStory = {
  render: (args) => (
    <PressabilityStory
      title="Pressability"
      description="Taps on the input claim the JS responder, so the parent Pressable's onPress does not fire. onPress still runs when editable is off; only the self-focus is skipped. hitSlop extends both the press handlers and the native touch target."
      onPress={args.onPress}
      onPressIn={args.onPressIn}
      onPressOut={args.onPressOut}
    />
  ),
};
