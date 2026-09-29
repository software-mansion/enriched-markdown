import { DEFAULT_NORMALIZED_STYLE } from '../../../normalizeMarkdownStyle.web';
import {
  DEFAULT_LINK_COLOR,
  DEFAULT_SPOILER_BG_COLOR,
  DEFAULT_SPOILER_COLOR,
} from '../../../normalizeMarkdownTextInputStyle';
import { injectStyleOnce } from '../../injectStyle';
import {
  HEADING_BLOCK_TYPES,
  LIST_INDENT_PER_DEPTH,
  MAX_LIST_DEPTH,
} from '../model/blocks';

export const ENRM_INPUT_CLASS = 'enrm-input';

const defaults = DEFAULT_NORMALIZED_STYLE;

function headingRules(): string {
  return HEADING_BLOCK_TYPES.map((level) => {
    const { fontSize, lineHeight, color, fontWeight } = defaults[level];
    return `.${ENRM_INPUT_CLASS} [data-block="${level}"] { font-size: ${fontSize}px; line-height: ${lineHeight}px; color: ${color}; font-weight: ${fontWeight}; }`;
  }).join('\n');
}

function bulletShape(depth: number): string {
  switch (depth % 3) {
    case 0:
      return 'background: currentColor; border-radius: 50%;';
    case 1:
      return 'border: 1px solid currentColor; border-radius: 50%;';
    default:
      return 'background: currentColor;';
  }
}

function listRules(): string {
  const rules: string[] = [];
  for (let depth = 0; depth <= MAX_LIST_DEPTH; depth++) {
    const indent = (depth + 1) * LIST_INDENT_PER_DEPTH;
    const markerLeft = depth * LIST_INDENT_PER_DEPTH;
    rules.push(
      `.${ENRM_INPUT_CLASS} [data-depth="${depth}"] { padding-left: ${indent}px; }`,
      `.${ENRM_INPUT_CLASS} [data-block="unordered-list-item"][data-depth="${depth}"]::before { left: ${markerLeft + 4}px; ${bulletShape(depth)} }`,
      `.${ENRM_INPUT_CLASS} [data-block="ordered-list-item"][data-depth="${depth}"]::before { left: ${markerLeft}px; }`
    );
  }
  return rules.join('\n');
}

const INPUT_CSS = `
.${ENRM_INPUT_CLASS} {
  white-space: pre-wrap;
  overflow-wrap: break-word;
  font-family: ${defaults.paragraph.fontFamily};
  font-size: ${defaults.paragraph.fontSize}px;
  line-height: ${defaults.paragraph.lineHeight}px;
  color: ${defaults.paragraph.color};
}
.${ENRM_INPUT_CLASS} [data-block] {
  position: relative;
}
.${ENRM_INPUT_CLASS} [data-block="unordered-list-item"]::before {
  content: '';
  position: absolute;
  top: ${defaults.list.lineHeight / 2 - 3}px;
  width: 6px;
  height: 6px;
  color: ${defaults.list.markerColor};
}
.${ENRM_INPUT_CLASS} [data-block="ordered-list-item"]::before {
  content: attr(data-ordinal) '.';
  position: absolute;
  width: 14px;
  text-align: right;
  white-space: nowrap;
  color: ${defaults.list.markerColor};
  font-weight: ${defaults.list.markerFontWeight};
}
${headingRules()}
${listRules()}
.${ENRM_INPUT_CLASS} .enrm-strong { font-weight: bold; }
.${ENRM_INPUT_CLASS} .enrm-em { font-style: italic; }
.${ENRM_INPUT_CLASS} .enrm-underline { text-decoration: underline; }
.${ENRM_INPUT_CLASS} .enrm-strikethrough { color: ${defaults.strikethrough.color}; text-decoration: line-through; }
.${ENRM_INPUT_CLASS} .enrm-underline.enrm-strikethrough { text-decoration: underline line-through; }
.${ENRM_INPUT_CLASS} .enrm-link { color: ${DEFAULT_LINK_COLOR}; text-decoration: underline; }
.${ENRM_INPUT_CLASS} .enrm-spoiler { color: ${DEFAULT_SPOILER_COLOR}; background: ${DEFAULT_SPOILER_BG_COLOR}; border-radius: 4px; }
`;

export function injectInputStyles(): void {
  injectStyleOnce('enrm-input-style', INPUT_CSS);
}
