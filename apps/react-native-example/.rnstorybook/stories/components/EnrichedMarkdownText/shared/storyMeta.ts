import type { Meta } from '@storybook/react-native';
import { EnrichedMarkdownText } from 'react-native-enriched-markdown';

export type StoryCategory = 'Block' | 'Inline' | 'Props' | 'Regression';

export function storyMeta(
  category: StoryCategory,
  name: string
): Meta<typeof EnrichedMarkdownText> {
  return {
    title: `EnrichedMarkdownText/${category}/${name}`,
    component: EnrichedMarkdownText,
    parameters: {
      controls: { exclude: ['markdown'] },
    },
  };
}
