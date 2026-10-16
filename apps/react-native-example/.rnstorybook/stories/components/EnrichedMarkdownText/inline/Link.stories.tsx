import React from 'react';
import { Image } from 'react-native';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import {
  fontFamilyControl,
  linkStyledDefaults,
  linkPillDefaults,
  linkVariantFontDefaults,
  linkVariantsDemoDefaults,
  type LinkPillControls,
  type LinkStyleControls,
  type LinkVariantFontControls,
  type LinkVariantsDemoControls,
} from '../shared/storybookMarkdownStyles';
import {
  splitStyleControls,
  toLinkPillStyle,
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

const PILLS_MARKDOWN =
  'Open [src/components/Button.tsx](https://example.com/files/src/components/Button.tsx), ' +
  'see [README.md](https://example.com/files/README.md), or visit [React Native](https://reactnative.dev).';

const PILL_ICON_URI = Image.resolveAssetSource(
  require('../../../../../src/assets/logo_icon.png')
).uri;

// Per-link content is separate from the style: one exact URL -> its label / icon.
const PILLS_CONTENT = {
  'https://example.com/files/src/components/Button.tsx': {
    label: 'Button.tsx',
  },
};

const pillsArgTypes = {
  pill: {
    control: 'boolean',
    description: 'markdownStyle.linkVariants["^https://example\\.com/"].pill',
  },
  color: { control: 'color', description: 'variant color (label)' },
  backgroundColor: { control: 'color', description: 'variant backgroundColor' },
  borderColor: { control: 'color', description: 'pill.borderColor' },
  borderWidth: { control: 'number', description: 'pill.borderWidth' },
  borderRadius: { control: 'number', description: 'pill.borderRadius' },
  paddingHorizontal: {
    control: 'number',
    description: 'pill.paddingHorizontal',
  },
  paddingVertical: { control: 'number', description: 'pill.paddingVertical' },
  maxWidth: {
    control: 'number',
    description: 'pill.maxWidth (0 = available text width)',
  },
  variantLabel: {
    control: 'text',
    description:
      'pill.label: shown by every matching link without its own content',
  },
  tintIcon: {
    control: 'boolean',
    description:
      'off: pill.iconTintColor is omitted and the icon keeps its colors',
  },
  iconTintColor: { control: 'color', description: 'pill.iconTintColor' },
};

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

export const Pills: TextStory<LinkPillControls> = {
  args: {
    markdown: PILLS_MARKDOWN,
    linkPillContent: PILLS_CONTENT,
    ...linkPillDefaults,
  },
  argTypes: pillsArgTypes,
  render: (args) => {
    const { controls, rest } = splitStyleControls(args, linkPillDefaults);
    return (
      <EnrichedMarkdownTextStory
        title="Link Pills"
        description="linkVariants[pattern].pill presents matching links as pills (iOS and Android). linkPillContent gives one exact URL its own label: the Button.tsx link uses it, README.md shows its link text, and the unmatched reactnative.dev link stays an ordinary link. pill.iconTintColor recolors the variant's icon and keeps its alpha."
        {...rest}
        style={toLinkPillStyle(controls, PILL_ICON_URI)}
      />
    );
  },
};
