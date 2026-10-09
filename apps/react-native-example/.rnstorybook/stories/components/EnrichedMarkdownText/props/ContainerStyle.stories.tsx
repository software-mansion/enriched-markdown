import React from 'react';
import type { ViewStyle } from 'react-native';
import { StyleSheet } from 'react-native';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { numberControl } from '../shared/storybookMarkdownStyles';
import { storyMeta } from '../shared/storyMeta';
import type { TextStory } from '../shared/storyTypes';

type ContainerStyleStoryExtra = {
  containerPadding: number;
  containerBackgroundColor: string;
};

const MARKDOWN = `First paragraph inside the container, long enough to wrap onto another line so the trailing edge padding stays visible.

Second paragraph with the same wrapper styling.`;

const argTypes = {
  containerPadding: numberControl('containerStyle.padding', {
    min: 0,
    max: 48,
    step: 4,
  }),
  containerBackgroundColor: {
    control: 'color',
    description: 'containerStyle.backgroundColor',
  },
};

export default storyMeta('Props', 'Container Style');

export const Default: TextStory<ContainerStyleStoryExtra> = {
  args: {
    markdown: MARKDOWN,
    containerPadding: 12,
    containerBackgroundColor: '#f3f4f6',
  },
  argTypes,
  render: ({ containerPadding, containerBackgroundColor, ...args }) => (
    <EnrichedMarkdownTextStory
      title="Container Style"
      description="containerStyle wraps the markdown output view."
      {...args}
      containerStyle={buildContainerStyle(
        containerPadding,
        containerBackgroundColor
      )}
    />
  ),
};

const styles = StyleSheet.create({
  container: {
    borderRadius: 8,
  },
});

function buildContainerStyle(
  padding: number,
  backgroundColor: string
): ViewStyle {
  return {
    ...styles.container,
    padding,
    backgroundColor,
  };
}
