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
});
