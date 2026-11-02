/**
 * @jest-environment jsdom
 */
import { ENRM_INPUT_CLASS, injectInputStyles } from '../inputStyles';

function rulesFor(selector: string): CSSStyleRule[] {
  return [...document.styleSheets]
    .flatMap((sheet) => [...sheet.cssRules])
    .filter(
      (rule): rule is CSSStyleRule =>
        rule instanceof CSSStyleRule && rule.selectorText === selector
    );
}

describe('input stylesheet', () => {
  beforeAll(() => injectInputStyles());

  // Switching thousands of laid-out lines from static to relative at once -
  // select-all into a list, or undoing out of one - cost Chromium seconds
  // of layout (undo of a select-all bullet list on 20k lines: 5.9 s, 0.2 s
  // with every line relative from the start). A block change must only
  // touch the block attributes.
  it('positions every line, whatever its block', () => {
    const lineRules = rulesFor(`.${ENRM_INPUT_CLASS} > *`);
    expect(
      lineRules.map((rule) => rule.style.getPropertyValue('position'))
    ).toContain('relative');

    const blockOnly = [...document.styleSheets]
      .flatMap((sheet) => [...sheet.cssRules])
      .filter(
        (rule): rule is CSSStyleRule =>
          rule instanceof CSSStyleRule &&
          rule.selectorText.includes('[data-') &&
          rule.style.getPropertyValue('position') !== ''
      )
      // Markers are absolutely positioned against their line; that is fine.
      .filter((rule) => !rule.selectorText.endsWith('::before'));
    expect(blockOnly.map((rule) => rule.selectorText)).toEqual([]);
  });

  // Review §2.7.6: the stylesheet is injected after the app's, so typography
  // at class specificity would beat a consumer's className.
  it('sets the base typography at zero specificity', () => {
    const typography = rulesFor(`:where(.${ENRM_INPUT_CLASS})`);
    expect(
      typography.map((rule) => rule.style.getPropertyValue('font-size'))
    ).not.toContain('');
    const root = rulesFor(`.${ENRM_INPUT_CLASS}`);
    expect(
      root.map((rule) => rule.style.getPropertyValue('font-size'))
    ).toEqual(root.map(() => ''));
  });

  // Review §2.7.2: the link's underline rule came later and dropped it.
  it('draws both lines on a struck-through link', () => {
    expect(
      rulesFor(`.${ENRM_INPUT_CLASS} .enrm-link.enrm-strikethrough`).map(
        (rule) => rule.style.getPropertyValue('text-decoration')
      )
    ).toEqual(['var(--enrm-link-struck-decoration, underline line-through)']);
  });

  // Review §2.7.3: a fixed 14px box let "10." run into the text. The edge is
  // logical so an RTL line puts its number on the right.
  it('anchors ordered markers on their inline-end edge', () => {
    for (const depth of [0, 2]) {
      const [rule] = rulesFor(
        `.${ENRM_INPUT_CLASS} [data-block="ordered-list-item"][data-depth="${depth}"]::before`
      );
      expect(rule!.style.getPropertyValue('inset-inline-end')).not.toBe('');
      expect(rule!.style.getPropertyValue('right')).toBe('');
      expect(rule!.style.getPropertyValue('left')).toBe('');
    }
  });

  it('indents and marks list lines with logical properties for RTL', () => {
    const [indent] = rulesFor(`.${ENRM_INPUT_CLASS} [data-depth="0"]`);
    expect(indent!.style.getPropertyValue('padding-inline-start')).not.toBe('');
    expect(indent!.style.getPropertyValue('padding-left')).toBe('');
    const [bullet] = rulesFor(
      `.${ENRM_INPUT_CLASS} [data-block="unordered-list-item"][data-depth="0"]::before`
    );
    expect(bullet!.style.getPropertyValue('inset-inline-start')).not.toBe('');
    expect(bullet!.style.getPropertyValue('left')).toBe('');
  });
});
