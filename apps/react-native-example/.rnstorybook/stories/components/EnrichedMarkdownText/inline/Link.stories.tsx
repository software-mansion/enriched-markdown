import React from 'react';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import {
  fontFamilyControl,
  linkStyledDefaults,
  linkVariantFontDefaults,
  linkVariantsDemoDefaults,
  type LinkStyleControls,
  type LinkVariantFontControls,
  type LinkVariantsDemoControls,
} from '../shared/storybookMarkdownStyles';
import {
  splitStyleControls,
  toLinkStyle,
  toLinkVariantFontStyle,
  toLinkVariantsDemoStyle,
} from '../shared/storybookStyleBuilders';
import type { TextStory } from '../shared/storyTypes';

type LinkInteractionsStoryExtra = {
  enableLinkPreview: boolean;
};

const MARKDOWN = 'Visit [React Native](https://reactnative.dev) for docs.';

const INTERACTIONS_MARKDOWN =
  '[React Native](https://reactnative.dev) and [Expo](https://expo.dev)';

const VARIANTS_MARKDOWN =
  'Hey [Alice](user:alice), check [general](channel:general) and [docs](https://example.com).';

const VARIANT_FONTS_MARKDOWN =
  'Base [React Native](https://reactnative.dev), mention [Alice](user:alice), and read [our docs](https://example.com/docs).';

const linkBaseArgTypes = {
  fontFamily: fontFamilyControl('markdownStyle.link.fontFamily'),
  color: {
    control: 'color',
    description: 'markdownStyle.link.color',
  },
  underline: {
    control: 'boolean',
    description: 'markdownStyle.link.underline',
  },
  backgroundColor: {
    control: 'color',
    description: 'markdownStyle.link.backgroundColor',
  },
};

const variantsArgTypes = {
  ...linkBaseArgTypes,
  color: {
    control: 'color',
    description: 'markdownStyle.link.color (fallback for unmatched URLs)',
  },
  userVariantColor: {
    control: 'color',
    description: 'markdownStyle.linkVariants["^user:"].color',
  },
  userVariantUnderline: {
    control: 'boolean',
    description: 'markdownStyle.linkVariants["^user:"].underline',
  },
  userVariantBackgroundColor: {
    control: 'color',
    description: 'markdownStyle.linkVariants["^user:"].backgroundColor',
  },
  channelVariantColor: {
    control: 'color',
    description: 'markdownStyle.linkVariants["^channel:"].color',
  },
  channelVariantUnderline: {
    control: 'boolean',
    description: 'markdownStyle.linkVariants["^channel:"].underline',
  },
  channelVariantBackgroundColor: {
    control: 'color',
    description: 'markdownStyle.linkVariants["^channel:"].backgroundColor',
  },
};

const variantFontsArgTypes = {
  fontFamily: fontFamilyControl('markdownStyle.link.fontFamily (base font)'),
  color: {
    control: 'color',
    description: 'markdownStyle.link.color',
  },
  userVariantFontFamily: fontFamilyControl(
    'markdownStyle.linkVariants["^user:"].fontFamily'
  ),
  docsVariantFontFamily: fontFamilyControl(
    'markdownStyle.linkVariants["^https://example\\.com/"].fontFamily'
  ),
};

const interactionsArgTypes = {
  enableLinkPreview: {
    control: 'boolean',
    description:
      'Show the native link preview on long-press (iOS). Defaults to false when onLinkLongPress is set.',
  },
  onLinkPress: { action: 'onLinkPress' },
  onLinkLongPress: { action: 'onLinkLongPress' },
};

export default storyMeta('Inline', 'Link');

export const Default: TextStory<LinkStyleControls> = {
  args: {
    markdown: MARKDOWN,
    ...linkStyledDefaults,
  },
  argTypes: linkBaseArgTypes,
  render: (args) => {
    const { controls, rest } = splitStyleControls(args, linkStyledDefaults);
    return (
      <EnrichedMarkdownTextStory
        title="Link"
        description="[text](url) renders a tappable link. Use the controls to tune markdownStyle.link."
        {...rest}
        style={{ link: toLinkStyle(controls) }}
      />
    );
  },
};

export const Interactions: TextStory<LinkInteractionsStoryExtra> = {
  args: {
    markdown: INTERACTIONS_MARKDOWN,
    enableLinkPreview: true,
  },
  argTypes: interactionsArgTypes,
  render: (args) => (
    <EnrichedMarkdownTextStory
      title="Link Interactions"
      description="Tap and long-press links. Wire onLinkPress / onLinkLongPress via the Actions panel."
      {...args}
    />
  ),
};

export const Variants: TextStory<LinkVariantsDemoControls> = {
  args: {
    markdown: VARIANTS_MARKDOWN,
    ...linkVariantsDemoDefaults,
  },
  argTypes: variantsArgTypes,
  render: (args) => {
    const { controls, rest } = splitStyleControls(
      args,
      linkVariantsDemoDefaults
    );
    return (
      <EnrichedMarkdownTextStory
        title="Link Variants"
        description="Per-URL-pattern overrides via markdownStyle.linkVariants. Unmatched links use the base link style."
        {...rest}
        style={toLinkVariantsDemoStyle(controls)}
      />
    );
  },
};

export const VariantFonts: TextStory<LinkVariantFontControls> = {
  args: {
    markdown: VARIANT_FONTS_MARKDOWN,
    ...linkVariantFontDefaults,
  },
  argTypes: variantFontsArgTypes,
  render: (args) => {
    const { controls, rest } = splitStyleControls(
      args,
      linkVariantFontDefaults
    );
    return (
      <EnrichedMarkdownTextStory
        title="Link Variant Fonts"
        description="Each linkVariant can override fontFamily. The user: and example.com links use their own fonts; the unmatched reactnative.dev link falls back to the base link font."
        {...rest}
        style={toLinkVariantFontStyle(controls)}
      />
    );
  },
};
