import { readFileSync } from 'fs';
import { join } from 'path';
import { blockIdentity, collectBlocks, fnv1a64Hex } from '../blockSlots';
import { parseMarkdown } from '../parseMarkdown';
import type { ASTNode } from '../types';

const text = (content: string): ASTNode => ({ type: 'Text', content });
const image = (url: string, alt = ''): ASTNode => ({
  type: 'Image',
  attributes: { url },
  children: alt ? [text(alt)] : [],
});
const paragraph = (...children: ASTNode[]): ASTNode => ({
  type: 'Paragraph',
  children,
});
const video = (url: string): ASTNode => ({
  type: 'Video',
  attributes: { url },
});

it('hashes like the C++ collector', () => {
  // The fixture is asserted by packages/core/cpp/tests/block_slots_test.cpp too.
  const fixture = readFileSync(
    join(__dirname, '../../../../core/cpp/tests/fixtures/block_slot_ids.txt'),
    'utf8'
  );
  const vectors = fixture
    .split('\n')
    .filter((line) => line.length > 0 && !line.startsWith('#'))
    .map((line) => line.split('\t') as [string, string]);
  expect(vectors.length).toBeGreaterThan(3);
  for (const [input, hash] of vectors) {
    expect(fnv1a64Hex(input.replaceAll('\\u001f', '\u001f'))).toBe(hash);
  }
});

it('collects the same ids as the C++ core from a shared document', async () => {
  // Both fixtures are asserted by packages/core/cpp/tests/block_slots_test.cpp too.
  const dir = join(__dirname, '../../../../core/cpp/tests/fixtures/block_ids');
  const doc = await parseMarkdown(
    readFileSync(join(dir, 'document.md'), 'utf8'),
    {}
  );
  const expected = readFileSync(join(dir, 'ids.txt'), 'utf8')
    .split('\n')
    .filter((line) => line.length > 0 && !line.startsWith('#'));
  const { blocks, images } = collectBlocks(doc);
  expect([...blocks.map((b) => b.id), ...images.map((i) => i.id)]).toEqual(
    expected
  );
});

it('collects standalone images and videos in document order with stable ids', () => {
  const doc: ASTNode = {
    type: 'Document',
    children: [
      paragraph(image('https://e.com/a.png', 'Hero')),
      paragraph(text('Inline '), image('https://e.com/a.png')),
      {
        type: 'UnorderedList',
        children: [
          {
            type: 'ListItem',
            children: [paragraph(image('https://e.com/b.png'))],
          },
        ],
      },
      {
        type: 'Blockquote',
        children: [paragraph(image('https://e.com/a.png'))],
      },
      { type: 'Admonition', children: [video('https://e.com/v.mp4')] },
      video('https://e.com/v.mp4'),
      {
        type: 'UnorderedList',
        children: [
          {
            type: 'ListItem',
            children: [
              {
                type: 'Blockquote',
                children: [paragraph(image('https://e.com/a.png'))],
              },
            ],
          },
        ],
      },
    ],
  };

  const { blocks, images } = collectBlocks(doc);
  const id = (prefix: string, url: string, alt = '', title = '') =>
    `${prefix}:${fnv1a64Hex(blockIdentity(url, alt, title))}`;
  const a = 'https://e.com/a.png';

  // The hash covers alt and title, so a.png with other alt text is another block.
  expect(blocks.map((b) => [b.kind, b.placement, b.id])).toEqual([
    ['image', 'root', `${id('image', a, 'Hero')}:0`],
    ['image', 'blockquote', `${id('image', a)}:0`],
    ['video', 'admonition', `${id('video', 'https://e.com/v.mp4')}:0`],
    ['video', 'root', `${id('video', 'https://e.com/v.mp4')}:1`],
  ]);
  expect(blocks[0]).toMatchObject({
    altText: 'Hero',
    url: a,
    occurrenceId: images[0]!.id,
  });
  expect(blocks[2]).not.toHaveProperty('altText');
  // Occurrence ids have their own prefix and count identical images.
  expect(images.map((i) => [i.placement, i.id])).toEqual([
    ['root', `${id('img', a, 'Hero')}:0`],
    ['inline', `${id('img', a)}:0`],
    ['list', `${id('img', 'https://e.com/b.png')}:0`],
    ['blockquote', `${id('img', a)}:1`],
    ['list', `${id('img', a)}:2`],
  ]);
  expect(blocks[1]).toMatchObject({ occurrenceId: images[3]!.id });

  // The walk stamps the ids the renderers read.
  expect(doc.children![0]!.attributes?.blockSlotId).toBe(blocks[0]!.id);
  expect(doc.children![0]!.children![0]!.attributes?.imageOccurrenceId).toBe(
    images[0]!.id
  );
  expect(doc.children![1]!.attributes?.blockSlotId).toBeUndefined();
  expect(doc.children![5]!.attributes?.blockSlotId).toBe(blocks[3]!.id);
  // A quote inside a list item is laid out as text natively: no slot.
  expect(
    doc.children![6]!.children![0]!.children![0]!.children![0]!.attributes
      ?.blockSlotId
  ).toBeUndefined();
});

it('treats a link-only paragraph as a link block and mixed images as text', () => {
  const doc: ASTNode = {
    type: 'Document',
    children: [
      paragraph({
        type: 'Link',
        attributes: { url: 'https://e.com' },
        children: [image('https://e.com/c.png', 'linked')],
      }),
      paragraph(image('https://e.com/c.png'), text(' caption')),
      paragraph({
        type: 'Link',
        attributes: { url: 'https://e.com/q3.pdf', title: 'application/pdf' },
        children: [text('Q3 report.pdf')],
      }),
      paragraph(text('See '), {
        type: 'Link',
        attributes: { url: 'https://e.com' },
        children: [text('docs')],
      }),
    ],
  };
  const { blocks, images } = collectBlocks(doc);
  expect(
    blocks.map((b) => [b.kind, b.id, (b as { label?: string }).label])
  ).toEqual([
    [
      'link',
      `link:${fnv1a64Hex(blockIdentity('https://e.com', 'linked'))}:0`,
      'linked',
    ],
    [
      'link',
      `link:${fnv1a64Hex(blockIdentity('https://e.com/q3.pdf', 'Q3 report.pdf', 'application/pdf'))}:0`,
      'Q3 report.pdf',
    ],
  ]);
  expect(blocks[1]).toMatchObject({ title: 'application/pdf' });
  expect(images.map((i) => i.placement)).toEqual(['link', 'inline']);
});

it('collects the pinned links from the shared document', async () => {
  // Both fixtures are asserted by packages/core/cpp/tests/block_slots_test.cpp.
  const dir = join(__dirname, '../../../../core/cpp/tests/fixtures/block_ids');
  const doc = await parseMarkdown(
    readFileSync(join(dir, 'document.md'), 'utf8'),
    {}
  );
  const expected = readFileSync(join(dir, 'links.txt'), 'utf8')
    .split('\n')
    .filter((line) => line.length > 0 && !line.startsWith('#'));
  expect(
    collectBlocks(doc).links.map(
      (link) => `${link.url}\t${link.label}\t${link.title}`
    )
  ).toEqual(expected);
});

it('reports every link in document order', async () => {
  const doc = await parseMarkdown(
    '# [h](https://e.com/h)\n\nSee [docs](https://e.com/d "Docs") and https://e.com/bare here\n\n' +
      '- <https://e.com/auto>\n\n| a |\n|---|\n| [cell](https://e.com/t) |\n\n' +
      '> www.example.com\n\n`https://e.com/code`\n',
    {}
  );
  const { links } = collectBlocks(doc);
  expect(links.map((link) => link.url)).toEqual([
    'https://e.com/h',
    'https://e.com/d',
    'https://e.com/bare',
    'https://e.com/auto',
    'https://e.com/t',
    'http://www.example.com',
  ]);
  expect(links[1]).toEqual({
    url: 'https://e.com/d',
    label: 'docs',
    title: 'Docs',
  });
  expect(links[5]).toMatchObject({ label: 'www.example.com' });
});
