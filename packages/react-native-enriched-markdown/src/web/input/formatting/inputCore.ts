/* eslint-disable no-bitwise -- heap addresses and int32 offsets */
import { getLoadedModule } from '../../parseMarkdown';
import type { Md4cModule } from '../../wasm/md4c';
import {
  createBlockRange,
  type BlockRange,
  type BlockType,
} from '../model/blocks';
import {
  createFormattingRange,
  INPUT_STYLE_TYPES,
  type FormattingRange,
} from '../model/inlineStyles';
import type { ParseResult } from './InputParser';

// The input's markdown import and export live in C++ (cpp/input) and reach the
// web through the md4c WASM module. Data crosses as plain heap memory: text and
// link URLs as UTF-16 code units, ranges as int32 records, no JSON. The record
// layouts are documented where the module is written, cpp/wasm/md4c_wasm.cpp.

// The numeric values of the C++ `BlockType`.
const BLOCK_TYPES: readonly BlockType[] = [
  'paragraph',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'unordered-list-item',
  'ordered-list-item',
];

const FORMATTING_INTS = 5;
const BLOCK_INTS = 5;
// Code units per String.fromCharCode call: spreading a whole document into the
// arguments would overflow the stack.
const DECODE_CHUNK = 8192;

function loadedModule(): Md4cModule {
  const module = getLoadedModule();
  if (module === null) {
    throw new Error('The markdown core is not loaded');
  }
  return module;
}

function decode(module: Md4cModule, pointer: number, length: number): string {
  const units = module.HEAPU16;
  const start = pointer >> 1;
  let text = '';
  for (let offset = 0; offset < length; offset += DECODE_CHUNK) {
    const chunk = units.subarray(
      start + offset,
      start + Math.min(length, offset + DECODE_CHUNK)
    );
    text += String.fromCharCode.apply(null, chunk as unknown as number[]);
  }
  return text;
}

function allocate(module: Md4cModule, bytes: number): number {
  // malloc(0) may return null, which the C++ side reads as an empty buffer.
  const pointer = module._malloc(Math.max(bytes, 8));
  if (pointer === 0) {
    throw new Error('The markdown core is out of memory');
  }
  return pointer;
}

// Re-reads the heap view after the allocation, which may have grown it.
function writeUnits(module: Md4cModule, text: string): number {
  const pointer = allocate(module, text.length * 2);
  const units = module.HEAPU16;
  const start = pointer >> 1;
  for (let index = 0; index < text.length; index++) {
    units[start + index] = text.charCodeAt(index);
  }
  return pointer;
}

export function isInputCoreLoaded(): boolean {
  return getLoadedModule() !== null;
}

/** Markdown to plain text and ranges. Throws if the module is not loaded. */
export function parseWithCore(markdown: string): ParseResult {
  const module = loadedModule();
  const input = writeUnits(module, markdown);
  try {
    const header = module._parseInput(input, markdown.length) >> 2;
    const ints = module.HEAP32;
    const plainText = decode(module, ints[header]!, ints[header + 1]!);

    const formattingBase = ints[header + 2]! >> 2;
    const formattingCount = ints[header + 3]!;
    const urlPool = ints[header + 6]!;
    const formattingRanges: FormattingRange[] = [];
    for (let index = 0; index < formattingCount; index++) {
      const record = formattingBase + index * FORMATTING_INTS;
      const type = INPUT_STYLE_TYPES[ints[record]!]!;
      // The core cannot tell an empty destination from none, and the parser
      // reports a link without a destination as having no url.
      const url =
        type === 'link'
          ? decode(
              module,
              urlPool + ints[record + 3]! * 2,
              ints[record + 4]!
            ) || undefined
          : undefined;
      formattingRanges.push(
        createFormattingRange(type, ints[record + 1]!, ints[record + 2]!, url)
      );
    }

    const blockBase = ints[header + 4]! >> 2;
    const blockCount = ints[header + 5]!;
    const blockRanges: BlockRange[] = [];
    for (let index = 0; index < blockCount; index++) {
      const record = blockBase + index * BLOCK_INTS;
      const block = createBlockRange(
        BLOCK_TYPES[ints[record]!]!,
        ints[record + 1]!,
        ints[record + 2]!,
        ints[record + 3]!
      );
      block.ordinal = ints[record + 4]!;
      blockRanges.push(block);
    }
    return { plainText, formattingRanges, blockRanges };
  } finally {
    module._free(input);
  }
}

/** Plain text and ranges to markdown. Throws if the module is not loaded. */
export function serializeWithCore(
  text: string,
  formattingRanges: readonly FormattingRange[],
  blockRanges: readonly BlockRange[]
): string {
  const module = loadedModule();
  const allocations: number[] = [];
  const track = (pointer: number) => {
    allocations.push(pointer);
    return pointer;
  };
  try {
    let urls = '';
    const urlOffsets: number[] = [];
    for (const range of formattingRanges) {
      urlOffsets.push(urls.length);
      urls += range.url ?? '';
    }
    const textPointer = track(writeUnits(module, text));
    const urlPointer = track(writeUnits(module, urls));
    const formattingPointer = track(
      allocate(module, formattingRanges.length * FORMATTING_INTS * 4)
    );
    const blockPointer = track(
      allocate(module, blockRanges.length * BLOCK_INTS * 4)
    );

    // Views are taken last: every allocation above may have grown the heap.
    const ints = module.HEAP32;
    formattingRanges.forEach((range, index) => {
      const record = (formattingPointer >> 2) + index * FORMATTING_INTS;
      ints[record] = INPUT_STYLE_TYPES.indexOf(range.type);
      ints[record + 1] = range.start;
      ints[record + 2] = range.end;
      ints[record + 3] = urlOffsets[index]!;
      ints[record + 4] = range.url?.length ?? 0;
    });
    blockRanges.forEach((block, index) => {
      const record = (blockPointer >> 2) + index * BLOCK_INTS;
      ints[record] = BLOCK_TYPES.indexOf(block.type);
      ints[record + 1] = block.start;
      ints[record + 2] = block.end;
      ints[record + 3] = block.level;
      ints[record + 4] = block.ordinal;
    });

    const header =
      module._serializeInput(
        textPointer,
        text.length,
        formattingPointer,
        formattingRanges.length,
        urlPointer,
        urls.length,
        blockPointer,
        blockRanges.length
      ) >> 2;
    const result = module.HEAP32;
    return decode(module, result[header]!, result[header + 1]!);
  } finally {
    for (const pointer of allocations) {
      module._free(pointer);
    }
  }
}
