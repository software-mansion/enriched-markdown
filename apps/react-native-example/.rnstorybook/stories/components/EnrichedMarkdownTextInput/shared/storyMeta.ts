import type { Meta } from '@storybook/react-native';
import { EnrichedMarkdownTextInput } from 'react-native-enriched-markdown';

export type InputStoryCategory = 'Inline' | 'Props' | 'Methods';

export const inputActionArgTypes = {
  onChangeMarkdown: { action: 'onChangeMarkdown' },
  onChangeText: { action: 'onChangeText' },
  onKeyPress: { action: 'onKeyPress' },
  onFocus: { action: 'onFocus' },
  onBlur: { action: 'onBlur' },
  onLinkDetected: { action: 'onLinkDetected' },
};

export function storyMeta(
  category: InputStoryCategory,
  name: string
): Meta<typeof EnrichedMarkdownTextInput> {
  return {
    title: `EnrichedMarkdownTextInput/${category}/${name}`,
    component: EnrichedMarkdownTextInput,
    parameters: {
      controls: { exclude: ['initialMarkdown'] },
    },
    argTypes: inputActionArgTypes,
  };
}
