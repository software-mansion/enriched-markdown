import React from 'react';
import {
  EnrichedMarkdownTextInputStory,
  StyleStateStory,
} from '../EnrichedMarkdownTextInputStory';
import { storyMeta } from '../shared/storyMeta';
import {
  inputLinkBaseArgTypes,
  inputLinkDefaults,
  inputLinkVariantsArgTypes,
  inputLinkVariantsDemoDefaults,
  type InputLinkStyleControls,
  type InputLinkVariantsDemoControls,
} from '../shared/storybookInputStyles';
import {
  splitStyleControls,
  toInputLinkStyle,
  toInputLinkVariantsDemoStyle,
} from '../shared/storybookInputStyleBuilders';
import type { InputStory } from '../shared/storyTypes';

const MARKDOWN = 'Visit [React Native](https://reactnative.dev) for docs.';

const VARIANTS_MARKDOWN =
  '[jira://PROJ-123](jira://PROJ-123), [sftp://server.example.com/file.zip](sftp://server.example.com/file.zip), [notion://page-abc](notion://page-abc), [https://example.com](https://example.com)';

export default storyMeta('Inline', 'Link');

export const Default: InputStory<InputLinkStyleControls> = {
  args: {
    initialMarkdown: MARKDOWN,
    ...inputLinkDefaults,
  },
  argTypes: inputLinkBaseArgTypes,
  render: (args) => {
    const { controls, rest } = splitStyleControls(args, inputLinkDefaults);
    return (
      <EnrichedMarkdownTextInputStory
        title="Link"
        description="[text](url) renders a styled link. Use the toolbar to set or insert links on the current selection."
        {...rest}
        markdownStyle={{ link: toInputLinkStyle(controls) }}
      />
    );
  },
};

export const Variants: InputStory<InputLinkVariantsDemoControls> = {
  args: {
    initialMarkdown: VARIANTS_MARKDOWN,
    ...inputLinkVariantsDemoDefaults,
  },
  argTypes: inputLinkVariantsArgTypes,
  render: (args) => {
    const { controls, rest } = splitStyleControls(
      args,
      inputLinkVariantsDemoDefaults
    );
    return (
      <EnrichedMarkdownTextInputStory
        title="Link Variants"
        description="linkVariants in markdownStyle styles links by URL scheme. Each key is a regex tested against the href — first match wins."
        {...rest}
        markdownStyle={toInputLinkVariantsDemoStyle(controls)}
      />
    );
  },
};

export const LinkState: InputStory = {
  argTypes: { onChangeState: { action: 'onChangeState' } },
  render: (args) => (
    <StyleStateStory
      title="Link State"
      description="styleState.link reports the link at the selection and its destination. Move the caret between the two adjacent links, place it right after a link, select across a link boundary and set a link, or put the caret in the empty-URL link (isActive: true, destination: '')."
      initialMarkdown="[one](https://one.example)[two](https://two.example) and [empty]()"
      onChangeState={args.onChangeState}
    />
  ),
};
