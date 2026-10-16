/**
 * @jest-environment jsdom
 */
import { DomRenderer } from '../DomRenderer';
import { projectParagraphs } from '../InputProjection';
import { BlockStore } from '../../formatting/BlockStore';
import { createBlockRange as block } from '../../model/blocks';
import type { BlockType } from '../../model/blocks';

type Line = string | [BlockType, string] | [BlockType, string, number];

// Lines as plain paragraphs or [type, text, level], numbered by the real
// store so ordinals follow the same rules as in the editor.
function project(lines: readonly Line[]) {
  const text = lines.map((line) => (typeof line === 'string' ? line : line[1]));
  const ranges = [];
  let at = 0;
  for (const [i, line] of lines.entries()) {
    if (typeof line !== 'string') {
      ranges.push(block(line[0], at, at + line[1].length, line[2] ?? 0));
    }
    at += text[i]!.length + 1;
  }
  const store = new BlockStore();
  store.setRanges(ranges);
  const joined = text.join('\n');
  return {
    text: joined,
    paragraphs: projectParagraphs(joined, [], store.allRanges),
  };
}

function render(renderer: DomRenderer, lines: readonly Line[]): void {
  const { text, paragraphs } = project(lines);
  renderer.render(text, paragraphs);
}

function describeLines(root: HTMLElement): string[] {
  return [...root.children].map((line) => {
    const { block: type, depth, ordinal } = (line as HTMLElement).dataset;
    return `${type ?? 'p'}:${depth ?? '-'}:${ordinal ?? '-'}:${line.textContent}`;
  });
}

// Plain strings, not records: a failing match on records that hold DOM nodes
// runs jest's diff out of memory.
function summarize(record: MutationRecord): string {
  switch (record.type) {
    case 'characterData':
      return 'text';
    case 'attributes':
      return `attr:${record.attributeName}`;
    default:
      return `lines:+${record.addedNodes.length}-${record.removedNodes.length}`;
  }
}

const count = (mutations: string[], kind: string) =>
  mutations.filter((mutation) => mutation === kind).length;

// Renders `before`, then `after`, and returns the mutations of the second
// render next to the DOM a fresh renderer builds for `after`.
function rerender(before: readonly Line[], after: readonly Line[]) {
  const root = document.createElement('div');
  const renderer = new DomRenderer(root);
  render(renderer, before);
  const observer = new MutationObserver(() => {});
  observer.observe(root, {
    subtree: true,
    childList: true,
    characterData: true,
    attributes: true,
  });
  render(renderer, after);
  const mutations = observer.takeRecords().map(summarize);
  observer.disconnect();

  const freshRoot = document.createElement('div');
  render(new DomRenderer(freshRoot), after);
  return {
    mutations,
    lines: describeLines(root),
    expected: describeLines(freshRoot),
  };
}

const items = (type: BlockType, length: number): Line[] =>
  Array.from({ length }, (_, i): Line => [type, `item ${i}`]);

const withEmptyAt = (
  lines: Line[],
  index: number,
  type: BlockType,
  level = 0
): Line[] => [
  ...lines.slice(0, index),
  [type, '', level],
  ...lines.slice(index),
];

describe('DomRenderer list edits', () => {
  it('inserts one line for Enter in a bullet list and leaves later items alone', () => {
    const before = items('unordered-list-item', 50);
    const { mutations, lines, expected } = rerender(
      before,
      withEmptyAt(before, 1, 'unordered-list-item')
    );

    expect(lines).toEqual(expected);
    expect(mutations).toEqual(['lines:+1-0']);
  });

  it('renumbers later ordered items without rewriting their text', () => {
    const before = items('ordered-list-item', 50);
    const { mutations, lines, expected } = rerender(
      before,
      withEmptyAt(before, 1, 'ordered-list-item')
    );

    expect(lines).toEqual(expected);
    expect(count(mutations, 'lines:+1-0')).toBe(1);
    expect(count(mutations, 'attr:data-ordinal')).toBe(49);
    expect(mutations).toHaveLength(50);
  });

  it('continues the numbering when the paragraph between two lists goes', () => {
    const first = items('ordered-list-item', 3);
    const second = items('ordered-list-item', 3);
    const { mutations, lines, expected } = rerender(
      [...first, 'between', ...second],
      [...first, ...second]
    );

    expect(lines).toEqual(expected);
    expect(lines.map((line) => line.split(':')[2])).toEqual([
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
    ]);
    expect(count(mutations, 'text')).toBe(0);
  });

  it('renumbers a nested ordered list and keeps the ones after it', () => {
    const nested = (text: string): Line => ['ordered-list-item', text, 1];
    const before: Line[] = [
      ['unordered-list-item', 'a'],
      nested('x'),
      nested('y'),
      nested('z'),
      ['unordered-list-item', 'b'],
      nested('u'),
      nested('v'),
      ['ordered-list-item', 'top'],
      ['ordered-list-item', 'top'],
    ];
    const { mutations, lines, expected } = rerender(
      before,
      withEmptyAt(before, 2, 'ordered-list-item', 1)
    );

    expect(lines).toEqual(expected);
    expect(lines.map((line) => line.split(':')[2])).toEqual([
      '-',
      '1',
      '2',
      '3',
      '4',
      '-',
      '1',
      '2',
      '1',
      '2',
    ]);
    expect(mutations).toEqual([
      'lines:+1-0',
      'attr:data-ordinal',
      'attr:data-ordinal',
    ]);
  });

  it('renumbers top-level items after a nested list the edit runs into', () => {
    // Toggling the bullet into an ordered item joins it to the list below,
    // so the walk has to cross the nested items to reach them.
    const before: Line[] = [
      ['unordered-list-item', 'a'],
      ['ordered-list-item', 'x', 1],
      ['ordered-list-item', 'b'],
      ['ordered-list-item', 'c'],
    ];
    const after: Line[] = [['ordered-list-item', 'a'], ...before.slice(1)];
    const { lines, expected } = rerender(before, after);

    expect(lines).toEqual(expected);
    expect(lines.map((line) => line.split(':')[2])).toEqual([
      '1',
      '1',
      '2',
      '3',
    ]);
  });
});

describe('DomRenderer inserts', () => {
  it('attaches the lines of a first render in one insert', () => {
    const root = document.createElement('div');
    const observer = new MutationObserver(() => {});
    observer.observe(root, { childList: true });
    render(new DomRenderer(root), items('ordered-list-item', 30));
    const mutations = observer.takeRecords().map(summarize);
    observer.disconnect();

    expect(mutations).toEqual(['lines:+30-0']);
    expect(describeLines(root)[29]).toBe('ordered-list-item:0:30:item 29');
  });

  it('attaches lines pasted mid-document in one insert, in order', () => {
    const before = items('unordered-list-item', 10);
    const pasted: Line[] = ['one', 'two', 'three'];
    const after = [...before.slice(0, 5), ...pasted, ...before.slice(5)];
    const { mutations, lines, expected } = rerender(before, after);

    expect(lines).toEqual(expected);
    expect(mutations).toEqual(['lines:+3-0']);
  });
});
