import React from 'react';
import { KeyPressStory } from '../EnrichedMarkdownTextInputStory';
import { storyMeta } from '../shared/storyMeta';
import type { InputStory } from '../shared/storyTypes';

export default storyMeta('Props', 'Key Press');

export const Default: InputStory = {
  render: (args) => (
    <KeyPressStory
      title="onKeyPress"
      description="Fires on every keystroke before it is applied to the content — nativeEvent.key is the pressed character, or Backspace / Enter. The latest keys show up below the input; every press is also logged to the Actions tab."
      onKeyPress={args.onKeyPress}
    />
  ),
};
