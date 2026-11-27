import { normalizeMarkdownStyle } from '../../normalizeMarkdownStyle.web';
import type { buildStyles as BuildStyles } from '../styles';

function inlineImageStyle(supportsCap: boolean) {
  const previous = (globalThis as { CSS?: unknown }).CSS;
  (globalThis as { CSS?: unknown }).CSS = { supports: () => supportsCap };
  try {
    let buildStyles: typeof BuildStyles | undefined;
    jest.isolateModules(() => {
      buildStyles = require('../styles').buildStyles;
    });
    return buildStyles!(normalizeMarkdownStyle({ inlineImage: { size: 48 } }))
      .inlineImage;
  } finally {
    (globalThis as { CSS?: unknown }).CSS = previous;
  }
}

describe('inline image style', () => {
  it('fits the image inside its square (#1083)', () => {
    expect(inlineImageStyle(true)).toMatchObject({
      width: 48,
      height: 48,
      objectFit: 'contain',
    });
  });

  it('centres on the cap height', () => {
    expect(inlineImageStyle(true).verticalAlign).toBe('calc(0.5cap - 24px)');
  });

  it('centres on the middle where `cap` is unsupported', () => {
    expect(inlineImageStyle(false).verticalAlign).toBe('middle');
  });
});
