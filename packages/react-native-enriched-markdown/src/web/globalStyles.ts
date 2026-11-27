import { injectStyleOnce } from './injectStyle';

export const ENRM_TEXT_CLASS = 'enrm-text';
export const ENRM_ADMONITION_CLASS = 'enrm-admonition';
export const ENRM_SELECTION_BG_VAR = '--enrm-selection-bg';
export const ENRM_SPOILER_CLASS = 'enrm-spoiler';
export const ENRM_SPOILER_CONTENT_CLASS = 'enrm-spoiler-content';
export const ENRM_SPOILER_IMAGE_CLASS = 'enrm-spoiler-image';
export const ENRM_SPOILER_IMAGE_COVER_CLASS = 'enrm-spoiler-image-cover';

const SPOILER_REVEAL = '450ms cubic-bezier(0.5, 1, 0.89, 1)';
const REVEALED_SPOILER = `.${ENRM_TEXT_CLASS} .${ENRM_SPOILER_CLASS}[data-revealed]`;
const REVEALED_CONTENT = `${REVEALED_SPOILER} > .${ENRM_SPOILER_CONTENT_CLASS}`;
const REVEALED_IMAGE_LAYERS =
  `${REVEALED_SPOILER} .${ENRM_SPOILER_IMAGE_COVER_CLASS}, ` +
  `${REVEALED_SPOILER} .${ENRM_SPOILER_IMAGE_CLASS}`;

export const ENRM_BULLET_COLOR_VAR = '--enrm-bullet-color';
export const ENRM_MARKER_COLOR_VAR = '--enrm-marker-color';
export const ENRM_MARKER_WEIGHT_VAR = '--enrm-marker-weight';
export const ENRM_TASK_CHECKBOX_CLASS = 'enrm-task-checkbox';
export const ENRM_CHECKMARK_COLOR_VAR = '--enrm-checkmark-color';
export const ENRM_CHECKMARK_SHAPE_VAR = '--enrm-checkmark-shape';

const RULES: ReadonlyArray<readonly [id: string, css: string]> = [
  [
    'enrm-selection-style',
    `.${ENRM_TEXT_CLASS} ::selection { background-color: var(${ENRM_SELECTION_BG_VAR}); }`,
  ],
  // Trim the trailing margin of a quote's last block so it doesn't add space
  // above the box's bottom padding, mirroring native. !important overrides the
  // per-element inline margin; the quote is a flex-item BFC so the margin can't
  // collapse out on its own.
  [
    'enrm-blockquote-trailing-margin',
    `.${ENRM_TEXT_CLASS} blockquote > *:last-child, ` +
      `.${ENRM_TEXT_CLASS} .${ENRM_ADMONITION_CLASS} > *:last-child { margin-bottom: 0 !important; }`,
  ],
  [
    'enrm-spoiler-reveal',
    `${REVEALED_SPOILER} { transition: background-color ${SPOILER_REVEAL}; } ` +
      `${REVEALED_CONTENT}, ${REVEALED_IMAGE_LAYERS} { transition: opacity ${SPOILER_REVEAL}; } ` +
      `@media (prefers-reduced-motion: reduce) { ` +
      `${REVEALED_SPOILER}, ${REVEALED_CONTENT}, ${REVEALED_IMAGE_LAYERS} { transition: none; } }`,
  ],
  [
    'enrm-list-markers',
    `.${ENRM_TEXT_CLASS} ul > li::marker { color: var(${ENRM_BULLET_COLOR_VAR}); } ` +
      `.${ENRM_TEXT_CLASS} ol > li::marker { color: var(${ENRM_MARKER_COLOR_VAR}); font-weight: var(${ENRM_MARKER_WEIGHT_VAR}); }`,
  ],
  [
    'enrm-task-checkmark',
    `.${ENRM_TEXT_CLASS} .${ENRM_TASK_CHECKBOX_CLASS}:checked::before { ` +
      'content: ""; position: absolute; inset: 0; ' +
      `background-color: var(${ENRM_CHECKMARK_COLOR_VAR}); ` +
      `clip-path: var(${ENRM_CHECKMARK_SHAPE_VAR}); }`,
  ],
  [
    'enrm-task-checkbox-forced-colors',
    '@media (forced-colors: active) { ' +
      `.${ENRM_TEXT_CLASS} .${ENRM_TASK_CHECKBOX_CLASS}:checked { background-color: CanvasText !important; } ` +
      `.${ENRM_TEXT_CLASS} .${ENRM_TASK_CHECKBOX_CLASS}:checked::before { background-color: Canvas; } }`,
  ],
];

for (const [id, css] of RULES) {
  injectStyleOnce(id, css);
}
