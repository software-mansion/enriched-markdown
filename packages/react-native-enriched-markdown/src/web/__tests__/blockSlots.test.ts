import { readFileSync } from 'fs';
import { join } from 'path';
import { collectBlocks, fnv1a64Hex } from '../blockSlots';
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
  for (const [url, hash] of vectors) {
    expect(fnv1a64Hex(url)).toBe(hash);
  }
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
  const hash = fnv1a64Hex('https://e.com/a.png');

  // Slot ids count slots only: the inline a.png does not shift the quoted one.
  expect(blocks.map((b) => [b.kind, b.placement, b.id])).toEqual([
    ['image', 'root', `image:${hash}:0`],
    ['image', 'blockquote', `image:${hash}:1`],
    ['video', 'admonition', `video:${fnv1a64Hex('https://e.com/v.mp4')}:0`],
    ['video', 'root', `video:${fnv1a64Hex('https://e.com/v.mp4')}:1`],
  ]);
  expect(blocks[0]).toMatchObject({
    altText: 'Hero',
    url: 'https://e.com/a.png',
  });
  expect(blocks[2]).not.toHaveProperty('altText');
  // Occurrence ids count every image of the url.
  expect(images.map((i) => [i.placement, i.id])).toEqual([
    ['root', `image:${hash}:0`],
    ['inline', `image:${hash}:1`],
    ['list', `image:${fnv1a64Hex('https://e.com/b.png')}:0`],
    ['blockquote', `image:${hash}:2`],
    ['list', `image:${hash}:3`],
  ]);

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
    ['link', `link:${fnv1a64Hex('https://e.com')}:0`, 'linked'],
    ['link', `link:${fnv1a64Hex('https://e.com/q3.pdf')}:0`, 'Q3 report.pdf'],
  ]);
  expect(blocks[1]).toMatchObject({ title: 'application/pdf' });
  expect(images.map((i) => i.placement)).toEqual(['link', 'inline']);
});
