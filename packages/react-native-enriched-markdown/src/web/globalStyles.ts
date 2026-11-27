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
];

for (const [id, css] of RULES) {
  injectStyleOnce(id, css);
}
