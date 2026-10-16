/**
 * @jest-environment jsdom
 */
import { DomRenderer } from '../../render/DomRenderer';
import { projectParagraphs } from '../../render/InputProjection';
import { createBlockRange as block } from '../../model/blocks';
import { createFormattingRange as range } from '../../model/inlineStyles';
import type { BlockRange } from '../../model/blocks';
import type { FormattingRange } from '../../model/inlineStyles';
import { SelectionMapper } from '../SelectionMapper';

function mount(
  text: string,
  formatting: FormattingRange[] = [],
  blocks: BlockRange[] = []
) {
  const root = document.createElement('div');
  document.body.appendChild(root);
  const renderer = new DomRenderer(root);
  renderer.render(text, projectParagraphs(text, formatting, blocks));
  return { root, mapper: new SelectionMapper(root, renderer) };
}

// Every offset has to survive the trip out to the DOM and back, since that is
// the loop every keystroke runs: the host writes the caret, the browser
// reports it back, and a lossy step there edits the wrong place.
function expectRoundTrip(
  text: string,
  formatting?: FormattingRange[],
  blocks?: BlockRange[]
) {
  const { mapper } = mount(text, formatting, blocks);
  for (let offset = 0; offset <= text.length; offset++) {
    const position = mapper.domPositionFromModelOffset(offset);
    expect(position).not.toBeNull();
    expect(mapper.modelOffsetFromDom(position!.node, position!.offset)).toBe(
      offset
    );
  }
}

describe('SelectionMapper', () => {
  it('round-trips every offset of a plain document', () => {
    expectRoundTrip('hello\nworld');
  });

  it('round-trips every offset across an empty line', () => {
    expectRoundTrip('a\n\nc');
  });

  it('round-trips every offset across run boundaries', () => {
    expectRoundTrip('abcdef', [range('strong', 2, 4), range('em', 3, 5)]);
  });

  it('round-trips every offset across block anchors', () => {
    expectRoundTrip('head\nitem\n', undefined, [
      { ...block('h1', 0, 4), level: 1 },
      block('unordered-list-item', 5, 9),
      { ...block('h2', 10, 10), level: 2 },
    ]);
  });

  it('round-trips every offset of a link run carrying a url', () => {
    expectRoundTrip('see here', [range('link', 4, 8, 'https://x.test')]);
  });

  it('maps a position at the document root to a line start', () => {
    const { root, mapper } = mount('ab\ncd');
    expect(mapper.modelOffsetFromDom(root, 0)).toBe(0);
    expect(mapper.modelOffsetFromDom(root, 1)).toBe(3);
    // One past the last line is the legitimate end-of-document position.
    expect(mapper.modelOffsetFromDom(root, 2)).toBe(5);
  });

  it('returns null for a node outside the editor', () => {
    const { mapper } = mount('ab');
    const outside = document.createElement('div');
    outside.textContent = 'elsewhere';
    document.body.appendChild(outside);
    expect(mapper.modelOffsetFromDom(outside.firstChild!, 1)).toBeNull();
  });

  describe('a DOM the projection does not describe', () => {
    let errors: jest.SpyInstance;

    beforeEach(() => {
      errors = jest.spyOn(console, 'error').mockImplementation(() => {});
    });

    afterEach(() => {
      errors.mockRestore();
    });

    // The one way a foreign node gets under the root is an IME writing
    // straight into the DOM. Counting child nodes rather than elements used
    // to shift every line after it, so a caret this file had just written
    // read back as a different line and the next keystroke edited there.
    it('a stray node under the root does not shift the lines', () => {
      const { root, mapper } = mount('hello\nworld');
      root.insertBefore(document.createTextNode('zz'), root.firstChild);

      for (const offset of [0, 3, 5, 6, 9, 11]) {
        const position = mapper.domPositionFromModelOffset(offset);
        expect(
          mapper.modelOffsetFromDom(position!.node, position!.offset)
        ).toBe(offset);
      }
    });

    it('a position inside a stray node maps to null, not to line zero', () => {
      const { root, mapper } = mount('ab\ncd');
      const stray = document.createTextNode('zz');
      root.appendChild(stray);

      expect(mapper.modelOffsetFromDom(stray, 2)).toBeNull();
      expect(errors).toHaveBeenCalled();
    });

    it('a stray node inside a line does not shift the offsets', () => {
      const { root, mapper } = mount('abcd');
      const line = root.firstElementChild!;
      line.insertBefore(document.createTextNode('ZZ'), line.firstChild);

      const position = mapper.domPositionFromModelOffset(2);
      expect(mapper.modelOffsetFromDom(position!.node, position!.offset)).toBe(
        2
      );
    });

    // A browser can leave a <br> behind in a line that has text. Treating it
    // as a run meant the real last span was not last, so the line-end caret
    // fell through to the line start and visibly jumped there on every render.
    it('a trailing <br> does not send the line-end caret to the line start', () => {
      const { root, mapper } = mount('ab\ncd');
      const line = root.firstElementChild!;
      line.appendChild(document.createElement('br'));

      const position = mapper.domPositionFromModelOffset(2);
      expect(position).not.toBeNull();
      expect(mapper.modelOffsetFromDom(position!.node, position!.offset)).toBe(
        2
      );
    });

    it('clamps a text offset past the end of its node', () => {
      const { root, mapper } = mount('ab\ncd');
      const textNode = root.firstElementChild!.firstElementChild!.firstChild!;

      expect(mapper.modelOffsetFromDom(textNode, 99)).toBe(2);
      expect(errors).not.toHaveBeenCalled();
    });

    it('reports a line shorter than the projection claims instead of guessing', () => {
      const { root, mapper } = mount('abcdef');
      root.firstElementChild!.replaceChildren();

      expect(mapper.domPositionFromModelOffset(4)).toBeNull();
      expect(errors).toHaveBeenCalled();
    });
  });
});
