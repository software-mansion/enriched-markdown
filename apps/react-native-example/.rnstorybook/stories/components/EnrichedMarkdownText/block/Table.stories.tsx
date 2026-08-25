import React from 'react';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import {
  fontFamilyControl,
  fontWeightControl,
  githubFlavorArgTypes,
  tableAlignControl,
  tableStyledDefaults,
  type TableStyleControls,
  numberControl,
} from '../shared/storybookMarkdownStyles';
import {
  splitStyleControls,
  toTableStyle,
} from '../shared/storybookStyleBuilders';
import type { TextStory } from '../shared/storyTypes';

const MARKDOWN = `| col1 | col2 | looooooooong col | a |
| - | -- | -------------------- | -------- |
| test | of | the | t |
| the | one | piece is | real
| third | Row | to test trailing | symbols | |asdf|||||blabla|`;

const WIDE_MARKDOWN = `| Product | Category | Q1 Revenue | Q2 Revenue | Q3 Revenue | Q4 Revenue | Total |
| --- | --- | --- | --- | --- | --- | --- |
| Widget Pro | Hardware | $12,400 | $15,200 | $14,800 | $18,100 | $60,500 |
| Cloud Suite | Software | $8,900 | $9,300 | $11,700 | $12,000 | $41,900 |
| Support Plan | Services | $4,200 | $4,500 | $4,800 | $5,100 | $18,600 |`;

const NARROW_MARKDOWN = `| Item | Qty |
| --- | --- |
| Apples | 3 |
| Pears | 7 |`;

const argTypes = {
  ...githubFlavorArgTypes('Tables require flavor="github" (GFM).'),
  fontSize: numberControl('markdownStyle.table.fontSize', {
    min: 10,
    max: 20,
    step: 1,
  }),
  fontFamily: fontFamilyControl('markdownStyle.table.fontFamily'),
  fontWeight: fontWeightControl('markdownStyle.table.fontWeight'),
  color: {
    control: 'color',
    description: 'markdownStyle.table.color',
  },
  marginTop: numberControl('markdownStyle.table.marginTop', {
    min: 0,
    max: 48,
    step: 2,
  }),
  marginBottom: numberControl('markdownStyle.table.marginBottom', {
    min: 0,
    max: 48,
    step: 2,
  }),
  lineHeight: numberControl('markdownStyle.table.lineHeight', {
    min: 14,
    max: 32,
    step: 1,
  }),
  headerFontFamily: fontFamilyControl('markdownStyle.table.headerFontFamily'),
  headerBackgroundColor: {
    control: 'color',
    description: 'markdownStyle.table.headerBackgroundColor',
  },
  headerTextColor: {
    control: 'color',
    description: 'markdownStyle.table.headerTextColor',
  },
  rowEvenBackgroundColor: {
    control: 'color',
    description: 'markdownStyle.table.rowEvenBackgroundColor',
  },
  rowOddBackgroundColor: {
    control: 'color',
    description: 'markdownStyle.table.rowOddBackgroundColor',
  },
  borderColor: {
    control: 'color',
    description: 'markdownStyle.table.borderColor',
  },
  borderWidth: numberControl('markdownStyle.table.borderWidth', {
    min: 0,
    max: 4,
    step: 1,
  }),
  borderRadius: numberControl('markdownStyle.table.borderRadius', {
    min: 0,
    max: 16,
    step: 1,
  }),
  cellPaddingHorizontal: numberControl(
    'markdownStyle.table.cellPaddingHorizontal',
    { min: 4, max: 24, step: 2 }
  ),
  cellPaddingVertical: numberControl(
    'markdownStyle.table.cellPaddingVertical',
    { min: 4, max: 24, step: 2 }
  ),
  horizontalOverflow: numberControl('markdownStyle.table.horizontalOverflow', {
    min: 0,
    max: 48,
    step: 2,
  }),
  align: tableAlignControl(
    "markdownStyle.table.align ('' = unset, legacy full-width table on web)"
  ),
};

export default storyMeta('Block', 'Table');

export const Default: TextStory<TableStyleControls> = {
  args: {
    markdown: MARKDOWN,
    flavor: 'github',
    ...tableStyledDefaults,
  },
  argTypes,
  render: (args) => {
    const { controls, rest } = splitStyleControls(args, tableStyledDefaults);
    return (
      <EnrichedMarkdownTextStory
        title="Table"
        description="GFM tables. Use the controls to tune markdownStyle.table."
        {...rest}
        style={{ table: toTableStyle(controls) }}
      />
    );
  },
};

export const Centered: TextStory<TableStyleControls> = {
  args: {
    markdown: NARROW_MARKDOWN,
    flavor: 'github',
    ...tableStyledDefaults,
    align: 'center',
  },
  argTypes,
  render: (args) => {
    const { controls, rest } = splitStyleControls(args, tableStyledDefaults);
    return (
      <EnrichedMarkdownTextStory
        title="Table Alignment"
        description="markdownStyle.table.align positions tables that are narrower than the container. Tables that overflow and scroll ignore it and start at the table's beginning."
        {...rest}
        style={{ table: toTableStyle(controls) }}
      />
    );
  },
};

export const HorizontalOverflow: TextStory<TableStyleControls> = {
  args: {
    markdown: WIDE_MARKDOWN,
    flavor: 'github',
    ...tableStyledDefaults,
    horizontalOverflow: 10,
  },
  argTypes,
  render: (args) => {
    const { controls, rest } = splitStyleControls(args, tableStyledDefaults);
    return (
      <EnrichedMarkdownTextStory
        title="Table Horizontal Overflow"
        description="Scrollable tables extend beyond the markdown container by markdownStyle.table.horizontalOverflow on each side (edge-to-edge layout). Set it to the parent's horizontal padding; here 10 matches the output box padding."
        {...rest}
        style={{ table: toTableStyle(controls) }}
      />
    );
  },
};
