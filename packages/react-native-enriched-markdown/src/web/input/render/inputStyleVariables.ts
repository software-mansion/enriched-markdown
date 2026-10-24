import type {
  HeadingStyle,
  MarkdownTextInputStyle,
} from '../../../types/MarkdownTextInputStyle';
import { DEFAULT_NORMALIZED_STYLE } from '../../../normalizeMarkdownStyle.web';
import { HEADING_BLOCK_TYPES } from '../model/blocks';

type HeadingLevelKey = (typeof HEADING_BLOCK_TYPES)[number];

// `markdownStyle` reaches the stylesheet as custom properties on the editor
// element, so each instance is themed without a stylesheet of its own. Every
// rule that reads one falls back to the default it had before.
export const inputStyleVar = {
  strongColor: '--enrm-strong-color',
  emColor: '--enrm-em-color',
  linkColor: '--enrm-link-color',
  linkBackground: '--enrm-link-bg',
  linkDecoration: '--enrm-link-decoration',
  linkStruckDecoration: '--enrm-link-struck-decoration',
  spoilerColor: '--enrm-spoiler-color',
  spoilerBackground: '--enrm-spoiler-bg',
  listItemSpacing: '--enrm-list-item-spacing',
  headingFontSize: (level: HeadingLevelKey) => `--enrm-${level}-font-size`,
  headingLineHeight: (level: HeadingLevelKey) => `--enrm-${level}-line-height`,
  headingFontWeight: (level: HeadingLevelKey) => `--enrm-${level}-font-weight`,
  headingColor: (level: HeadingLevelKey) => `--enrm-${level}-color`,
} as const;

function headingVariables(
  level: HeadingLevelKey,
  heading: HeadingStyle | undefined,
  out: Record<string, string>
): void {
  if (heading === undefined) {
    return;
  }
  if (heading.fontSize !== undefined) {
    // The line height keeps the default's proportion, so a bigger heading
    // does not overlap the line above it.
    const { fontSize, lineHeight } = DEFAULT_NORMALIZED_STYLE[level];
    out[inputStyleVar.headingFontSize(level)] = `${heading.fontSize}px`;
    out[inputStyleVar.headingLineHeight(level)] =
      `${Math.round((heading.fontSize * lineHeight) / fontSize)}px`;
  }
  if (heading.fontWeight !== undefined) {
    out[inputStyleVar.headingFontWeight(level)] = heading.fontWeight;
  }
  if (heading.color !== undefined) {
    out[inputStyleVar.headingColor(level)] = heading.color;
  }
}

// `linkVariants` is not mapped: it styles links by url pattern, which a
// per-element custom property cannot express.
export function inputStyleVariables(
  style: MarkdownTextInputStyle | undefined
): Record<string, string> {
  const out: Record<string, string> = {};
  if (style === undefined) {
    return out;
  }
  if (style.strong?.color !== undefined) {
    out[inputStyleVar.strongColor] = style.strong.color;
  }
  if (style.em?.color !== undefined) {
    out[inputStyleVar.emColor] = style.em.color;
  }
  if (style.link?.color !== undefined) {
    out[inputStyleVar.linkColor] = style.link.color;
  }
  if (style.link?.backgroundColor !== undefined) {
    out[inputStyleVar.linkBackground] = style.link.backgroundColor;
  }
  if (style.link?.underline === false) {
    out[inputStyleVar.linkDecoration] = 'none';
    out[inputStyleVar.linkStruckDecoration] = 'line-through';
  }
  if (style.spoiler?.color !== undefined) {
    out[inputStyleVar.spoilerColor] = style.spoiler.color;
  }
  if (style.spoiler?.backgroundColor !== undefined) {
    out[inputStyleVar.spoilerBackground] = style.spoiler.backgroundColor;
  }
  if (style.list?.itemSpacing !== undefined) {
    out[inputStyleVar.listItemSpacing] = `${style.list.itemSpacing}px`;
  }
  for (const level of HEADING_BLOCK_TYPES) {
    headingVariables(level, style[level], out);
  }
  return out;
}
