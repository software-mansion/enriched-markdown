import { DEFAULT_NORMALIZED_STYLE } from '../../../normalizeMarkdownStyle.web';
import {
  DEFAULT_LINK_BG_COLOR,
  DEFAULT_LINK_COLOR,
  DEFAULT_SPOILER_BG_COLOR,
  DEFAULT_SPOILER_COLOR,
} from '../../../inputStyleDefaults';
import { injectStyleOnce } from '../../injectStyle';
import {
  HEADING_BLOCK_TYPES,
  LIST_INDENT_PER_DEPTH,
  MAX_LIST_DEPTH,
} from '../model/blocks';
import { inputStyleVar } from './inputStyleVariables';

export const ENRM_INPUT_CLASS = 'enrm-input';
// Set with `data-selection-color` by the `selectionColor` prop. Only then
// does the `::selection` rule apply: an unset variable there would replace
// the browser's own highlight with none.
export const ENRM_INPUT_SELECTION_VAR = '--enrm-input-selection-bg';

const defaults = DEFAULT_NORMALIZED_STYLE;

function headingRules(): string {
  return HEADING_BLOCK_TYPES.map((level) => {
    const { fontSize, lineHeight, color, fontWeight } = defaults[level];
    return `.${ENRM_INPUT_CLASS} [data-block="${level}"] { font-size: var(${inputStyleVar.headingFontSize(level)}, ${fontSize}px); line-height: var(${inputStyleVar.headingLineHeight(level)}, ${lineHeight}px); color: var(${inputStyleVar.headingColor(level)}, ${color}); font-weight: var(${inputStyleVar.headingFontWeight(level)}, ${fontWeight}); }`;
  }).join('\n');
}

// Dot, then ring, then square for everything deeper - the cap the native
// drawers use and what a browser's own `ul` markers do.
function bulletShape(depth: number): string {
  switch (Math.min(depth, 2)) {
    case 0:
      return 'background: currentColor; border-radius: 50%;';
    case 1:
      return 'border: 1px solid currentColor; border-radius: 50%;';
    default:
      return 'background: currentColor;';
  }
}

// Space between an ordered marker's "." and the item's text.
const ORDERED_MARKER_GAP = 4;

function listRules(): string {
  const rules: string[] = [];
  for (let depth = 0; depth <= MAX_LIST_DEPTH; depth++) {
    const indent = (depth + 1) * LIST_INDENT_PER_DEPTH;
    const markerLeft = depth * LIST_INDENT_PER_DEPTH;
    rules.push(
      `.${ENRM_INPUT_CLASS} [data-depth="${depth}"] { padding-left: ${indent}px; }`,
      `.${ENRM_INPUT_CLASS} [data-block="unordered-list-item"][data-depth="${depth}"]::before { left: ${markerLeft + 4}px; ${bulletShape(depth)} }`,
      // The number grows leftward from a fixed end, as on native, so "10."
      // and up do not run into the text.
      `.${ENRM_INPUT_CLASS} [data-block="ordered-list-item"][data-depth="${depth}"]::before { right: calc(100% - ${indent - ORDERED_MARKER_GAP}px); }`
    );
  }
  return rules.join('\n');
}

const INPUT_CSS = `
.${ENRM_INPUT_CLASS} {
  white-space: pre-wrap;
  position: relative;
  overflow-wrap: break-word;
}
/* Typography at zero specificity, so a consumer's className overrides it:
   the stylesheet is injected after the app's, and a same-specificity rule
   here would otherwise win. */
:where(.${ENRM_INPUT_CLASS}) {
  font-family: ${defaults.paragraph.fontFamily};
  font-size: ${defaults.paragraph.fontSize}px;
  line-height: ${defaults.paragraph.lineHeight}px;
  color: ${defaults.paragraph.color};
}
.${ENRM_INPUT_CLASS}[data-empty]::before {
  content: attr(data-placeholder);
  position: absolute;
  top: 0;
  left: 0;
  padding: inherit;
  color: var(--enrm-placeholder-color, #9ca3af);
  pointer-events: none;
  white-space: pre-wrap;
}
/* Every line, not only those with a block: a list or heading marker is
   positioned against its line, and switching thousands of laid-out lines
   from static to relative at once (select-all into a list, or its undo)
   costs Blink seconds of layout - 2.5 s for 20k lines, against 0.14 s when
   only the block attributes change. */
.${ENRM_INPUT_CLASS} > * {
  position: relative;
}
/* A margin, not padding: the markers are positioned inside the line's box. */
.${ENRM_INPUT_CLASS} [data-block$="list-item"] {
  margin-top: var(${inputStyleVar.listItemSpacing}, 0px);
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
  text-align: right;
  white-space: nowrap;
  color: ${defaults.list.markerColor};
  font-weight: ${defaults.list.markerFontWeight};
}
${headingRules()}
${listRules()}
.${ENRM_INPUT_CLASS}[data-selection-color] ::selection {
  background-color: var(${ENRM_INPUT_SELECTION_VAR});
}
/* With the variable unset, color is invalid at computed-value time and
   inherits, so bold and italic keep the surrounding color by default. */
.${ENRM_INPUT_CLASS} .enrm-strong { font-weight: bold; color: var(${inputStyleVar.strongColor}); }
.${ENRM_INPUT_CLASS} .enrm-em { font-style: italic; color: var(${inputStyleVar.emColor}); }
.${ENRM_INPUT_CLASS} .enrm-underline { text-decoration: underline; }
.${ENRM_INPUT_CLASS} .enrm-strikethrough { color: ${defaults.strikethrough.color}; text-decoration: line-through; }
.${ENRM_INPUT_CLASS} .enrm-underline.enrm-strikethrough { text-decoration: underline line-through; }
.${ENRM_INPUT_CLASS} .enrm-link { color: var(${inputStyleVar.linkColor}, ${DEFAULT_LINK_COLOR}); background-color: var(${inputStyleVar.linkBackground}, ${DEFAULT_LINK_BG_COLOR}); text-decoration: var(${inputStyleVar.linkDecoration}, underline); }
.${ENRM_INPUT_CLASS} .enrm-link.enrm-strikethrough { text-decoration: var(${inputStyleVar.linkStruckDecoration}, underline line-through); }
.${ENRM_INPUT_CLASS} .enrm-spoiler { color: var(${inputStyleVar.spoilerColor}, ${DEFAULT_SPOILER_COLOR}); background: var(${inputStyleVar.spoilerBackground}, ${DEFAULT_SPOILER_BG_COLOR}); border-radius: 4px; }
`;

export function injectInputStyles(): void {
  injectStyleOnce('enrm-input-style', INPUT_CSS);
}
