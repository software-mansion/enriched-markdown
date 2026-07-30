import AsyncStorage from '@react-native-async-storage/async-storage';
import { LiteUI } from '@storybook/react-native-ui-lite';

import { view } from './storybook.requires';

// Without hasStoryWrapper: false, storybook wraps every story in a View whose
// onStartShouldSetResponder calls Keyboard.dismiss() on every touch start.
// That breaks text selection inside EnrichedMarkdownTextInput stories: tapping
// a selection handle dismisses the keyboard, the input resigns focus and the
// selection collapses (double-tap selection also gets flaky).
const StorybookUIRoot = view.getStorybookUI({
  hasStoryWrapper: false,
  shouldPersistSelection: true,
  storage: {
    getItem: AsyncStorage.getItem,
    setItem: AsyncStorage.setItem,
  },
  CustomUIComponent: LiteUI,
});

export default StorybookUIRoot;
